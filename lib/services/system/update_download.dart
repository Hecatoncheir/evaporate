import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'proxy_http_overrides.dart';
import 'app_log.dart';
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

/// Скачивает обновление, проверяет его и распаковывает.
///
/// Проверка не формальность. Канал защищён TLS, но оборванная загрузка
/// выглядит как целый файл, и распаковывать её поверх установки — верный
/// способ оставить человека без работающего приложения. Поэтому сначала
/// размер, потом sha256 из `SHA256SUMS`, и только потом распаковка.
///
/// Ничего не заменяется: результат — распакованная папка рядом. Заменой
/// занимается скрипт-помощник уже после выхода приложения.
class UpdateDownload {
  UpdateDownload({
    required this.workDir,
    Future<List<int>> Function(Uri uri, void Function(int, int) onProgress)?
    fetch,
  }) : _fetch = fetch ?? _httpFetch;

  /// Куда складывать скачанное — папка данных приложения.
  final String workDir;

  final Future<List<int>> Function(
    Uri uri,
    void Function(int received, int total) onProgress,
  )
  _fetch;

  /// Готовит обновление и возвращает папку, которой предстоит заменить
  /// установку.
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
    final archive = release.archiveForThisPlatform;
    if (archive == null) {
      throw const UpdateException('Для этой системы файла в релизе нет');
    }

    final dir = Directory(p.join(workDir, 'updates', release.version));
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);

    onProgress?.call(
      UpdateProgress(phase: UpdatePhase.downloading, total: archive.sizeBytes),
    );
    final bytes = await _fetch(
      Uri.parse(archive.url),
      (received, total) => onProgress?.call(
        UpdateProgress(
          phase: UpdatePhase.downloading,
          received: received,
          total: total > 0 ? total : archive.sizeBytes,
        ),
      ),
    );

    onProgress?.call(const UpdateProgress(phase: UpdatePhase.verifying));
    await _verify(release, archive, bytes);

    onProgress?.call(const UpdateProgress(phase: UpdatePhase.unpacking));
    final staged = Directory(p.join(dir.path, 'staged'));
    await staged.create(recursive: true);
    await _unpack(archive.name, bytes, staged.path);

    final root = await _rootOf(staged);
    onProgress?.call(const UpdateProgress(phase: UpdatePhase.ready));
    return root;
  }

  /// Размер и контрольная сумма.
  ///
  /// Сумма не защищает от подменённого источника — она приходит оттуда же,
  /// — но ловит оборванную и побитую загрузку, а это самое частое.
  Future<void> _verify(
    Release release,
    ReleaseAsset archive,
    List<int> bytes,
  ) async {
    if (archive.sizeBytes > 0 && bytes.length != archive.sizeBytes) {
      throw UpdateException(
        'Скачано ${bytes.length} байт вместо ${archive.sizeBytes}',
      );
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
    final actual = sha256.convert(bytes).toString();
    if (actual != expected) {
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
    final data = Uint8List.fromList(bytes);
    final Archive archive;
    try {
      archive = name.endsWith('.tar.gz')
          ? TarDecoder().decodeBytes(GZipDecoder().decodeBytes(data))
          : ZipDecoder().decodeBytes(data);
    } on Object catch (error) {
      throw UpdateException('Архив не читается: $error');
    }

    for (final file in archive.files) {
      // Та же мерка, что и у пакетов сохранений: архив приехал из сети, и
      // выход за пределы папки в нём недопустим.
      final relative = file.name.replaceAll(r'\', '/');
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
      // Запись про корень архива: создавать нечего, целевая папка уже есть.
      if (parts.isEmpty) continue;
      final destination = p.normalize(p.joinAll([target, ...parts]));
      if (!p.isWithin(target, destination)) {
        throw UpdateException('Архив просит записать файл наружу: $relative');
      }

      if (!file.isFile) {
        await Directory(destination).create(recursive: true);
        continue;
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
