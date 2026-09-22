import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../core/format.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';
import 'app_log.dart';
import 'update_check.dart';
import 'update_exception.dart';
import 'update_signature.dart';
import 'update_transport.dart';
import 'update_unpack.dart';

// Исключение переехало в свой файл, но зовут его отсюда уже по всему
// приложению: пусть оно так и остаётся видимым.
export 'update_exception.dart';

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

/// Скачивает и проверяет обновление.
///
/// Проверка не формальность. Канал защищён TLS, но оборванная загрузка
/// выглядит как целый файл, и распаковывать её поверх установки — верный
/// способ оставить человека без работающего приложения. Поэтому сначала
/// размер, потом подпись под `SHA256SUMS`, потом sha256 из него, и только
/// потом распаковка.
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
    AppLog Function()? log,
    this._signature = const UpdateSignature(),
    L Function()? localizations,
  }) : _platform = platform ?? currentPlatformKey(),
       _fetch = fetch ?? UpdateTransport.fetch,
       _download = download ?? UpdateTransport.download,
       _log = log ?? _appLog,
       _localizations = localizations ?? _defaultLocalizations;

  /// Куда складывать скачанное — папка данных приложения.
  final String workDir;

  /// Куда писать о ходе загрузки. Функцией — как `L Function()` у блоков:
  /// журнал заводится в `main`, а в тестах подменяется без правки глобала.
  final AppLog Function() _log;

  static AppLog _appLog() => AppLog.instance;
  final String _platform;

  /// Чьей подписи верим — подменяется в прогоне своим ключом.
  final UpdateSignature _signature;

  /// Сообщения отсюда человек читает в карточке обновления, а
  /// `BuildContext` здесь взять неоткуда.
  final L Function() _localizations;

  L get _l => _localizations();

  static L _defaultLocalizations() => LRu();

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
      _log().write('обновление ${release.version} не подготовилось', error);
      rethrow;
    }
  }

  Future<String> _prepare(
    Release release, {
    void Function(UpdateProgress)? onProgress,
  }) async {
    final asset = release.updateFor(_platform);
    if (asset == null) throw UpdateException(_l.updateNoFile);
    void report(UpdatePhase phase) =>
        onProgress?.call(UpdateProgress(phase: phase));

    // Папку версии не чистим: в ней мог остаться недокачанный кусок, и
    // вся затея докачки в том, чтобы продолжить его, а не начать заново.
    final dir = Directory(p.join(workDir, 'updates', release.version));
    await dir.create(recursive: true);
    final target = File(p.join(dir.path, asset.name));

    await _fetchPart(asset, target, onProgress);
    report(UpdatePhase.verifying);
    await _promote(release, asset, target);

    // На Windows ничего не распаковываем: Inno Setup сам заменит файлы
    // после закрытия приложения. Запускаем его напрямую, чтобы PowerShell
    // не был промежуточным процессом.
    if (_platform == 'windows') {
      report(UpdatePhase.ready);
      return target.path;
    }

    report(UpdatePhase.unpacking);
    final root = await UpdateUnpack.stage(dir, asset.name, target.path);
    report(UpdatePhase.ready);
    return root;
  }

  /// Докачивает файл рядом с целью.
  ///
  /// Пока файл не проверен, он лежит под своим именем с хвостом `.part`:
  /// целым считается только переименованный, и оборванная загрузка не
  /// выдаёт себя за готовое обновление.
  Future<void> _fetchPart(
    ReleaseAsset asset,
    File target,
    void Function(UpdateProgress)? onProgress,
  ) async {
    final part = File('${target.path}.part');
    onProgress?.call(
      UpdateProgress(phase: UpdatePhase.downloading, total: asset.sizeBytes),
    );

    final done = await part.exists() ? await part.length() : 0;
    // Уже целый кусок не перекачиваем — ему осталась только проверка.
    if (asset.sizeBytes > 0 && done >= asset.sizeBytes) return;

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

  /// Проверенный кусок становится самим файлом обновления.
  Future<void> _promote(
    Release release,
    ReleaseAsset asset,
    File target,
  ) async {
    final part = File('${target.path}.part');
    await _verify(release, asset, part);
    if (await target.exists()) await target.delete();
    await part.rename(target.path);
  }

  /// Размер, подпись под суммами и сама сумма.
  ///
  /// Сумма ловит оборванную и побитую загрузку, подлинность держит
  /// подпись: суммы кладёт в релиз то же задание, что и сборки, и тот, кто
  /// сумел выложить релиз, выложил бы и их. Проверить нечем — нет подписи,
  /// нет сумм, нет в них своего файла — значит не ставить: на Windows
  /// скачанный установщик запускается молча.
  Future<void> _verify(Release release, ReleaseAsset archive, File file) async {
    // Не сошлось — недокачанное выбрасываем. Иначе следующая попытка
    // продолжила бы с середины испорченного файла и не сошлась бы уже
    // никогда: докачка чинит обрыв связи, а не подмену байтов.
    final size = await file.length();
    if (archive.sizeBytes > 0 && size != archive.sizeBytes) {
      await file.delete();
      _log().write(
        'обновление: скачано $size байт вместо ${archive.sizeBytes}',
      );
      throw UpdateException(_l.updateIncomplete);
    }

    final expected = _sumFor(await _signedSums(release), archive.name);
    if (expected == null) {
      throw UpdateException(_l.updateNotListed(archive.name));
    }
    // Считаем по потоку: сборка весит десятки мегабайт, и держать её в
    // памяти целиком незачем.
    final actual = (await sha256.bind(file.openRead()).first).toString();
    if (actual != expected) {
      await file.delete();
      throw UpdateException(_l.updateChecksumMismatch);
    }
  }

  /// Файл сумм релиза, если под ним стоит подпись того, кому верим.
  Future<String> _signedSums(Release release) async {
    final sums = release.checksums;
    final signature = release.signature;
    if (sums == null || signature == null) {
      _log().write('обновление ${release.version}: в релизе нет подписи');
      throw UpdateException(_l.updateUnsigned);
    }
    final List<int> text;
    final List<int> signed;
    try {
      text = await _fetch(Uri.parse(sums.url), (_, _) {});
      signed = await _fetch(Uri.parse(signature.url), (_, _) {});
    } on Object catch (error) {
      _log().write('обновление: суммы или подпись не получены', error);
      throw UpdateException(_l.updateSignatureUnavailable);
    }
    if (!await _signature.verify(text, signed)) {
      _log().write('обновление ${release.version}: подпись не сошлась');
      throw UpdateException(_l.updateSignatureInvalid);
    }
    return String.fromCharCodes(text);
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
}
