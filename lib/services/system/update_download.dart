import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../core/format.dart';
import 'app_log.dart';
import 'proxy_http_overrides.dart';
import 'update_check.dart';

/// Что сейчас происходит с обновлением.
enum UpdatePhase { downloading, verifying, unpacking, ready, failed }

/// Ход подготовки обновления.
class UpdateProgress {
  const UpdateProgress({
    required this.phase,
    this.received = 0,
    this.total = 0,
    this.message,
  });

  final UpdatePhase phase;
  final int received;
  final int total;

  /// Чем именно не получилось — показывают человеку.
  final String? message;

  /// Доля скачанного или `null`, пока размер неизвестен.
  double? get fraction => total > 0 ? (received / total).clamp(0.0, 1.0) : null;
}

class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Скачивает и проверяет обновление.
///
/// Проверка не формальность. Канал защищён TLS, но оборванная загрузка
/// выглядит как целый файл, и распаковывать её поверх установки — верный
/// способ оставить человека без работающего приложения. Поэтому сначала
/// размер, потом sha256 из `SHA256SUMS`, и только потом распаковка.
///
/// На Windows результат — готовый Inno Setup. На macOS и Linux архив
/// распаковывается в папку, которую заменит POSIX-помощник после
/// выхода приложения.
class UpdateDownload {
  UpdateDownload({
    required this.workDir,
    String? platform,
    Future<List<int>> Function(Uri uri, void Function(int, int) onProgress)?
    fetch,
    Future<void> Function(
      Uri uri,
      File target,
      int from,
      void Function(int received, int total) onProgress,
    )?
    download,
  }) : _platform = platform ?? currentPlatformKey(),
       _fetch = fetch ?? _httpFetch,
       _download = download ?? _httpDownload;

  /// Куда складывать скачанное — папка данных приложения.
  final String workDir;
  final String _platform;

  /// Мелочь вроде `SHA256SUMS` — её проще прочитать целиком.
  final Future<List<int>> Function(
    Uri uri,
    void Function(int received, int total) onProgress,
  )
  _fetch;

  /// Сама сборка — десятки мегабайт, и она пишется прямо на диск.
  final Future<void> Function(
    Uri uri,
    File target,
    int from,
    void Function(int received, int total) onProgress,
  )
  _download;

  /// Готовит обновление и возвращает setup или корень распакованной сборки.
  Future<String> prepare(
    Release release, {
    void Function(UpdateProgress)? onProgress,
  }) async {
    try {
      return await _prepare(release, onProgress: onProgress);
    } on Object catch (error) {
      // Журнал ведёт сервис, а не виджет: у экрана нет ни языка для таких
      // записей, ни права их писать — там всё видимое переводится.
      AppLog.instance.write(
        'обновление ${release.version} не подготовилось',
        error,
      );
      rethrow;
    }
  }

  Future<String> _prepare(
    Release release, {
    void Function(UpdateProgress)? onProgress,
  }) async {
    final asset = release.updateFor(_platform);
    if (asset == null) {
      throw const UpdateException('Для этой системы файла в релизе нет');
    }

    // Папку версии не чистим: в ней мог остаться недокачанный кусок, и
    // вся затея докачки в том, чтобы продолжить его, а не начать заново.
    final dir = Directory(p.join(workDir, 'updates', release.version));
    await dir.create(recursive: true);

    final target = File(p.join(dir.path, asset.name));
    // Пока файл не проверен, он лежит под своим именем с хвостом: целым
    // считается только переименованный, и оборванная загрузка не выдаёт
    // себя за готовое обновление.
    final part = File('${target.path}.part');

    onProgress?.call(
      UpdateProgress(phase: UpdatePhase.downloading, total: asset.sizeBytes),
    );

    final done = await part.exists() ? await part.length() : 0;
    // Уже целый кусок не перекачиваем — ему осталась только проверка.
    if (asset.sizeBytes <= 0 || done < asset.sizeBytes) {
      await _download(
        Uri.parse(asset.url),
        part,
        done,
        (received, total) => onProgress?.call(
          UpdateProgress(
            phase: UpdatePhase.downloading,
            received: received,
            total: total > 0 ? total : asset.sizeBytes,
          ),
        ),
      );
    }

    onProgress?.call(const UpdateProgress(phase: UpdatePhase.verifying));
    await _verify(release, asset, part);
    if (await target.exists()) await target.delete();
    await part.rename(target.path);

    // На Windows ничего не распаковываем: Inno Setup сам заменит
    // файлы после закрытия приложения. Запускаем его напрямую,
    // чтобы PowerShell не был промежуточным процессом.
    if (_platform == 'windows') {
      onProgress?.call(const UpdateProgress(phase: UpdatePhase.ready));
      return target.path;
    }

    onProgress?.call(const UpdateProgress(phase: UpdatePhase.unpacking));
    final staged = Directory(p.join(dir.path, 'staged'));
    if (await staged.exists()) await staged.delete(recursive: true);
    await staged.create(recursive: true);
    await _unpack(asset.name, await target.readAsBytes(), staged.path);

    final root = await _rootOf(staged);
    onProgress?.call(const UpdateProgress(phase: UpdatePhase.ready));
    return root;
  }

  /// Размер и контрольная сумма.
  ///
  /// Сумма не защищает от подменённого источника — она приходит оттуда же,
  /// — но ловит оборванную и побитую загрузку, а это самое частое.
  Future<void> _verify(Release release, ReleaseAsset archive, File file) async {
    // Не сошлось — недокачанное выбрасываем. Иначе следующая попытка
    // продолжила бы с середины испорченного файла и не сошлась бы уже
    // никогда: докачка чинит обрыв связи, а не подмену байтов.
    final size = await file.length();
    if (archive.sizeBytes > 0 && size != archive.sizeBytes) {
      await file.delete();
      throw UpdateException('Скачано $size байт вместо ${archive.sizeBytes}');
    }

    final sums = release.checksums;
    if (sums == null) return;

    final List<int> raw;
    try {
      raw = await _fetch(Uri.parse(sums.url), (_, _) {});
    } on Object {
      // Файла сумм может не быть у старых релизов — размера уже достаточно.
      return;
    }

    final expected = _sumFor(String.fromCharCodes(raw), archive.name);
    if (expected == null) return;
    // Считаем по потоку: сборка весит десятки мегабайт, и держать её в
    // памяти целиком незачем.
    final actual = (await sha256.bind(file.openRead()).first).toString();
    if (actual != expected) {
      await file.delete();
      throw const UpdateException(
        'Контрольная сумма не сошлась: файл скачался повреждённым',
      );
    }
  }

  /// Строка вида `<sha256>  <имя файла>` — формат `sha256sum`.
  static String? _sumFor(String sums, String name) {
    for (final line in sums.split('\n')) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      if (p.basename(parts.last) == name) return parts.first.toLowerCase();
    }
    return null;
  }

  Future<void> _unpack(String name, List<int> bytes, String target) async {
    final archive = _readArchive(name, bytes);
    for (final file in archive.files) {
      final destination = _safeDestination(file.name, target);
      // Запись про корень архива: создавать нечего, целевая папка уже есть.
      if (destination == null) continue;
      await _extract(file, destination);
    }
  }

  /// Разбирает скачанное: `.tar.gz` на Linux, zip на остальных.
  static Archive _readArchive(String name, List<int> bytes) {
    final data = Uint8List.fromList(bytes);
    try {
      return name.endsWith('.tar.gz')
          ? TarDecoder().decodeBytes(const GZipDecoder().decodeBytes(data))
          : ZipDecoder().decodeBytes(data);
    } on Object catch (error) {
      throw UpdateException('Архив не читается: $error');
    }
  }

  /// Куда положить одну запись архива. `null` — записи про корень архива:
  /// создавать нечего, целевая папка уже есть.
  ///
  /// Та же мерка, что и у пакетов сохранений: архив приехал из сети, и
  /// выход за пределы папки в нём недопустим.
  static String? _safeDestination(String entryName, String target) {
    final relative = entryName.replaceAll(r'\', '/');
    // Пустые куски пути выходом наружу не являются: так записана обычная
    // папка (`data/flutter_assets/assets/`), так же выглядит и двойной
    // слеш. Отбрасываем их и разбираем то, что осталось, — иначе
    // обновление спотыкалось о первую же папку в архиве.
    final parts = [
      for (final part in relative.split('/'))
        if (part.isNotEmpty) part,
    ];
    if (parts.any((part) => part == '.' || part == '..')) {
      throw UpdateException('Архив просит записать файл наружу: $relative');
    }
    if (parts.isEmpty) return null;

    final destination = p.normalize(p.joinAll([target, ...parts]));
    if (!p.isWithin(target, destination)) {
      throw UpdateException('Архив просит записать файл наружу: $relative');
    }
    return destination;
  }

  /// Кладёт одну запись архива на своё место.
  static Future<void> _extract(ArchiveFile file, String destination) async {
    if (file.isSymbolicLink) {
      await _link(file, destination);
      return;
    }
    if (!file.isFile) {
      await Directory(destination).create(recursive: true);
      return;
    }
    final out = File(destination);
    await out.parent.create(recursive: true);
    final sink = OutputFileStream(destination);
    try {
      file.writeContent(sink);
    } finally {
      await sink.close();
    }
    // Права в zip не переживают распаковку, а запускать после обновления
    // придётся именно эти файлы.
    if (!Platform.isWindows && _looksExecutable(file)) {
      await Process.run('chmod', ['+x', destination]);
    }
  }

  /// Восстанавливает символическую ссылку.
  ///
  /// Бандл macOS без них не запускается: `Versions/Current` и сам бинарник
  /// фреймворка — ссылки, и CI пакует архив `ditto` именно ради них. Ляг
  /// ссылка обычным файлом с путём внутри, приложение не стартовало бы, а
  /// помощник к тому времени уже убрал прежнюю копию.
  ///
  /// Ссылка — такой же способ записать наружу, как `..` в имени: всё, что
  /// потом ляжет «внутрь» неё, ляжет туда, куда она указывает. Поэтому
  /// принимаем только относительные ссылки вниз, без `..`: каждая указывает
  /// в свою же папку или глубже, и цепочка таких ссылок наружу не выводит
  /// ни при каком порядке записей. Проверять по буквам «внутри ли корня»
  /// мало — через уже развёрнутую ссылку на `.` буквальный путь врёт.
  /// Ссылок вверх в бандле нет, и им неоткуда взяться.
  static Future<void> _link(ArchiveFile file, String destination) async {
    final raw = file.symbolicLink!.replaceAll(r'\', '/');
    final target = p.posix.normalize(raw);
    if (p.posix.isAbsolute(raw) || p.posix.split(target).contains('..')) {
      throw UpdateException(
        'Ссылка в архиве указывает наружу: ${file.name} -> $raw',
      );
    }
    await Directory(p.dirname(destination)).create(recursive: true);
    await Link(destination).create(target);
  }

  /// Похож ли файл на тот, которому нужен бит запуска.
  ///
  /// В zip права хранятся в верхних битах внешних атрибутов; там, где их
  /// нет, ориентируемся на расположение — в бандле macOS исполняемое лежит
  /// в `Contents/MacOS`.
  static bool _looksExecutable(ArchiveFile file) {
    final mode = file.mode;
    if (mode != 0 && (mode & 0x49) != 0) return true;
    return file.name.contains('/MacOS/') || !file.name.contains('.');
  }

  /// Папка, которой предстоит заменить установку.
  ///
  /// Архивы собраны по-разному: у macOS внутри лежит `.app`, у остальных —
  /// содержимое папки приложения россыпью. Разбираем по тому, что видим, а
  /// не по системе: так же поступит и человек, распаковавший архив руками.
  static Future<String> _rootOf(Directory staged) async {
    final entries = await staged.list(followLinks: false).toList();
    final bundles = entries.whereType<Directory>().where(
      (dir) => p.extension(dir.path) == '.app',
    );
    if (bundles.isNotEmpty) return bundles.first.path;
    // Единственная папка внутри — это она и есть.
    final dirs = entries.whereType<Directory>().toList();
    if (dirs.length == 1 && entries.length == 1) return dirs.single.path;
    return staged.path;
  }

  /// Качает файл в [target], продолжая с байта [from].
  ///
  /// Докачка нужна не ради экономии трафика: полсотни мегабайт по плохому
  /// каналу обрываются регулярно, а без продолжения каждая попытка
  /// начинается с нуля — то есть на таком канале не заканчивается никогда.
  static Future<void> _httpDownload(
    Uri uri,
    File target,
    int from,
    void Function(int, int) onProgress,
  ) async {
    final client = directHttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final response = await _open(client, uri, from);
      // Просим больше, чем файл занимает: значит он уже весь у нас, и
      // сказать об этом должна проверка суммы, а не отказ загрузки.
      if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
        await response.drain<void>();
        return;
      }
      // Докачку сервер поддерживать не обязан: не умеет — отвечает целым
      // файлом и кодом 200, и тогда прежний кусок надо выбросить, а не
      // дописать к нему второй.
      final resumed = response.statusCode == HttpStatus.partialContent;
      if (!resumed && response.statusCode != HttpStatus.ok) {
        throw UpdateException('Сервер ответил ${response.statusCode}');
      }
      await _writeBody(
        response,
        target,
        alreadyHave: resumed ? from : 0,
        append: resumed,
        onProgress: onProgress,
      );
    } on SocketException catch (error) {
      throw UpdateException('Нет связи: ${error.message}');
    } finally {
      client.close(force: true);
    }
  }

  /// Как часто докладываем о ходе загрузки. Кусков приходят тысячи, и
  /// перерисовывать окно на каждый значит тратить на показ больше, чем на
  /// саму загрузку.
  static const _progressInterval = Duration(milliseconds: 100);

  /// Пишет тело ответа в файл, изредка сообщая о ходе.
  static Future<void> _writeBody(
    HttpClientResponse response,
    File target, {
    required int alreadyHave,
    required bool append,
    required void Function(int, int) onProgress,
  }) async {
    var received = alreadyHave;
    final total = response.contentLength > 0
        ? response.contentLength + received
        : 0;
    final sink = target.openWrite(
      mode: append ? FileMode.append : FileMode.writeOnly,
    );
    var reported = DateTime.now();
    try {
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        final now = DateTime.now();
        if (now.difference(reported) < _progressInterval) continue;
        reported = now;
        onProgress(received, total);
      }
    } finally {
      await sink.close();
    }
    onProgress(received, total);
  }

  /// Запрос с продолжением и переадресациями.
  ///
  /// Диапазон переезжает вместе с запросом: GitHub уводит на своё
  /// хранилище, и докачивать предстоит уже там.
  static Future<HttpClientResponse> _open(
    HttpClient client,
    Uri uri,
    int from,
  ) async {
    var target = uri;
    for (var hop = 0; hop <= 5; hop++) {
      final request = await client.getUrl(target);
      if (from > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$from-');
      }
      final response = await request.close();
      if (!response.isRedirect) return response;
      final location = response.headers.value(HttpHeaders.locationHeader);
      if (location == null) return response;
      await response.drain<void>();
      target = target.resolve(location);
    }
    throw const UpdateException('Слишком много переадресаций');
  }

  static Future<List<int>> _httpFetch(
    Uri uri,
    void Function(int, int) onProgress,
  ) async {
    final client = directHttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      var request = await client.getUrl(uri);
      var response = await request.close();
      // GitHub отдаёт файлы релиза через переадресацию на своё хранилище.
      var hops = 0;
      while (response.isRedirect && hops++ < 5) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null) break;
        await response.drain<void>();
        request = await client.getUrl(uri.resolve(location));
        response = await request.close();
      }
      if (response.statusCode != 200) {
        throw UpdateException('Сервер ответил ${response.statusCode}');
      }

      final total = response.contentLength;
      final builder = BytesBuilder(copy: false);
      var reported = DateTime.now();
      await for (final chunk in response) {
        builder.add(chunk);
        final now = DateTime.now();
        if (now.difference(reported) < const Duration(milliseconds: 100)) {
          continue;
        }
        reported = now;
        onProgress(builder.length, total);
      }
      onProgress(builder.length, total);
      return builder.takeBytes();
    } on SocketException catch (error) {
      throw UpdateException('Нет связи: ${error.message}');
    } finally {
      client.close(force: true);
    }
  }
}
