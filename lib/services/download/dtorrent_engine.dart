import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dtorrent_task_v2/dtorrent_task_v2.dart' as dt;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/json_store.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';
import '../../models/download_task.dart';
import '../../models/speed_limits.dart';
import '../../models/proxy_settings.dart';
import 'download_engine.dart';
import 'torrent_file.dart';

/// Что нашла проверка файлов после загрузки.
class IntegrityReport {
  const IntegrityReport({
    required this.checkedFiles,
    this.missing = const [],
    this.truncated = const [],
    this.skipped = false,
  });

  /// Проверять было нечего: метаданные ещё не получены.
  const IntegrityReport.skipped() : this(checkedFiles: 0, skipped: true);

  final int checkedFiles;

  /// Файлов из раздачи нет на диске.
  final List<String> missing;

  /// Файлы есть, но размер меньше заявленного — загрузка оборвана.
  final List<String> truncated;
  final bool skipped;

  bool get isValid => missing.isEmpty && truncated.isEmpty;

  String describe(L l) {
    if (skipped) return l.nothingToVerify;
    if (isValid) return l.filesInPlace(checkedFiles);
    final parts = <String>[
      if (missing.isNotEmpty) l.filesMissing(missing.length),
      if (truncated.isNotEmpty) l.filesTruncated(truncated.length),
    ];
    return parts.join(', ');
  }
}

/// Движок загрузок на чистом Dart поверх `dtorrent_task_v2`.
///
/// В отличие от aria2, здесь SOCKS5 применяется и к обмену с пирами, а не
/// только к трекерам — ради этого движок и выбран. Внешнего бинарника нет,
/// поэтому движок «готов» сразу после запуска.
class DtorrentEngine implements DownloadEngine {
  DtorrentEngine({
    required this.downloadDir,
    required String stateFile,
    required this.torrentsDir,
    ProxySettings proxy = const ProxySettings(),
    this.maxConcurrent = 3,
    this.autoStart = true,
    L Function()? localizations,
  }) : _localizations = localizations ?? _defaultLocalizations,
       _store = JsonStore(stateFile) {
    _proxy = proxy;
  }

  /// Откуда брать переводы: сообщения движка доходят до пользователя
  /// уведомлениями, а `BuildContext` здесь взять неоткуда.
  final L Function() _localizations;

  L get _l => _localizations();

  static L _defaultLocalizations() => LRu();

  String downloadDir;

  /// Куда складывать `.torrent` раздач. Magnet-ссылка приносит метаданные
  /// один раз и из сети; сохранённый файл избавляет от повторного их поиска
  /// после перезапуска — и его же потом отдают на экспорт.
  final String torrentsDir;

  /// Сколько задач качается одновременно; остальные ждут очереди.
  int maxConcurrent;

  /// В тестах выключается, чтобы движок не лез в сеть: очередь и состояние
  /// проверяются без единого соединения.
  final bool autoStart;
  final JsonStore _store;
  late ProxySettings _proxy;

  final _status = ValueNotifier<EngineStatus>(
    const EngineStatus(EngineState.stopped),
  );
  final _tasks = ValueNotifier<List<DownloadTask>>(const []);
  final _stats = ValueNotifier<EngineStats>(const EngineStats());

  final Map<String, _ManagedDownload> _downloads = {};

  /// Порядок очереди, заданный пользователем. Именно он решает, кто займёт
  /// освободившийся слот, поэтому хранится отдельно от карты задач.
  final List<String> _order = [];
  Timer? _pollTimer;

  @override
  ValueListenable<EngineStatus> get status => _status;

  @override
  ValueListenable<List<DownloadTask>> get tasks => _tasks;

  @override
  ValueListenable<EngineStats> get stats => _stats;

  ProxySettings get proxy => _proxy;

  /// Смена прокси применяется к новым соединениям: уже поднятые задачи
  /// перезапускаются, иначе трафик продолжил бы идти по-старому.
  Future<void> setProxy(ProxySettings value) async {
    if (value == _proxy) return;
    _proxy = value;
    await _restartAll();
  }

  @override
  Future<void> start() async {
    if (_status.value.state == EngineState.ready) return;
    _status.value = const EngineStatus(EngineState.starting);
    try {
      await Directory(downloadDir).create(recursive: true);
      await _restoreState();
      _status.value = const EngineStatus(EngineState.ready);
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => refresh());
      await refresh();
    } on Object catch (error) {
      _status.value = EngineStatus(
        EngineState.failed,
        message: _l.engineStartFailed('$error'),
      );
    }
  }

  @override
  Future<void> stop() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    for (final managed in _downloads.values) {
      await managed.dispose();
    }
    _downloads.clear();
    _order.clear();
    _tasks.value = const [];
    _stats.value = const EngineStats();
    _status.value = const EngineStatus(EngineState.stopped);
  }

  Future<void> _restartAll() async {
    final snapshot = _downloads.values.toList();
    for (final managed in snapshot) {
      await managed.dispose();
    }
    pumpQueue();
    await refresh();
  }

  // ------------------------------------------------------------ добавление

  @override
  Future<String> addMagnet(String uri, {required String dir}) async {
    final trimmed = uri.trim();
    if (!trimmed.startsWith('magnet:')) {
      throw DownloadEngineException(_l.notAMagnetLink);
    }

    final dt.MagnetLink? link;
    try {
      link = dt.MagnetParser.parse(trimmed);
    } on Object catch (error) {
      throw DownloadEngineException(_l.magnetParseFailed('$error'));
    }
    if (link == null) {
      throw DownloadEngineException(_l.noInfohash);
    }

    final infoHash = _hex(link.infoHash);
    if (_downloads.containsKey(infoHash)) return infoHash;

    final managed = _ManagedDownload(
      infoHash: infoHash,
      savePath: dir,
      name: link.displayName ?? _l.torrentNamed(infoHash),
      magnet: trimmed,
      engine: this,
    );
    _register(managed);
    await _persist();
    pumpQueue();
    return infoHash;
  }

  @override
  Future<String> addTorrentFile(String path, {required String dir}) async {
    final file = File(path);
    if (!await file.exists()) {
      throw DownloadEngineException(_l.fileNotFound(path));
    }

    final dt.TorrentModel model;
    try {
      model = await parseTorrent(path);
    } on Object catch (error) {
      throw DownloadEngineException(_l.torrentReadFailed('$error'));
    }

    final infoHash = model.infoHash.toLowerCase();
    if (_downloads.containsKey(infoHash)) return infoHash;

    final managed = _ManagedDownload(
      infoHash: infoHash,
      savePath: dir,
      name: model.name,
      torrentPath: path,
      engine: this,
    )..model = model;
    _register(managed);
    await _persist();
    pumpQueue();
    return infoHash;
  }

  /// Читает `.torrent` с диска.
  static Future<dt.TorrentModel> parseTorrent(String path) async =>
      torrentFromBytes(await File(path).readAsBytes());

  /// Разбирает `.torrent`, пересчитывая infohash по байтам info-словаря.
  ///
  /// Разборщик библиотеки свой infohash не считает, а угадывает: ищет в файле
  /// байты `info` и закрывающую скобку, принимая за границы словаря первые
  /// же `d` и `e` — а они сплошь и рядом попадаются внутри двоичных хешей
  /// кусков. На настоящей раздаче он промахивается всегда, и с промахнувшимся
  /// хешем раздачу не узнают ни трекер, ни пир. Заодно возвращаем имени
  /// кириллицу: там оно читается как латиница, байт за символ.
  ///
  /// Открыто для тестов: сверить хеш можно на собранном в памяти торренте,
  /// без диска и без сети.
  @visibleForTesting
  static dt.TorrentModel torrentFromBytes(Uint8List bytes) {
    final model = dt.TorrentParser.parseBytes(bytes);
    final infoDict = TorrentFile.infoDictIn(bytes);
    // Хеш v2-раздачи считается иначе (sha256), и такие раздачи здесь ещё
    // не встречались — трогаем только то, о чём знаем наверняка.
    if (infoDict == null || model.version != dt.TorrentVersion.v1) return model;
    return dt.TorrentModel(
      name: TorrentFile.name(infoDict) ?? model.name,
      files: model.files,
      infoHashBuffer: Uint8List.fromList(sha1.convert(infoDict).bytes),
      pieceLength: model.pieceLength,
      pieces: model.pieces,
      announces: model.announces,
      nodes: model.nodes,
      length: model.length,
      version: model.version,
      metaVersion: model.metaVersion,
      fileTree: model.fileTree,
      pieceLayers: model.pieceLayers,
      rootHash: model.rootHash,
      infoDictBytes: infoDict,
      rawData: model.rawData,
    );
  }

  void _register(_ManagedDownload managed) {
    _downloads[managed.infoHash] = managed;
    if (!_order.contains(managed.infoHash)) _order.add(managed.infoHash);
  }

  /// Запускает ожидающие задачи, пока есть свободные слоты.
  ///
  /// Вызывается и снаружи: при смене числа одновременных загрузок
  /// освободившиеся слоты нужно раздать сразу.
  void pumpQueue() {
    for (final managed in _ordered) {
      if (_activeCount >= maxConcurrent) return;
      if (managed.started || managed.pausedByUser || managed.error != null) {
        continue;
      }
      managed.started = true;
      if (autoStart) {
        if (managed.task != null) {
          managed.task!.resume();
        } else {
          unawaited(_launch(managed));
        }
      }
    }
  }

  /// Кто занял слоты очереди. Открыто для тестов: иначе очередь пришлось бы
  /// проверять по сетевым эффектам.
  @visibleForTesting
  Set<String> get startedIds =>
      _downloads.values.where((d) => d.started).map((d) => d.infoHash).toSet();

  int get _activeCount =>
      _downloads.values.where((d) => d.started && !d.pausedByUser).length;

  Iterable<_ManagedDownload> get _ordered sync* {
    for (final id in _order) {
      final managed = _downloads[id];
      if (managed != null) yield managed;
    }
  }

  /// Переставляет задачу в очереди. Уже запущенные задачи не трогаем:
  /// перезапуск ради порядка рвал бы соединения с пирами.
  Future<void> reorder(String id, int newIndex) async {
    final from = _order.indexOf(id);
    if (from == -1) return;
    final target = newIndex.clamp(0, _order.length - 1);
    if (from == target) return;

    _order.removeAt(from);
    _order.insert(target, id);
    await _persist();
    pumpQueue();
    await refresh();
  }

  /// Позиция в очереди — её показывает интерфейс.
  int positionOf(String id) => _order.indexOf(id);

  /// Файл раздачи, если движок им располагает.
  ///
  /// Для торрента это то, что дали при добавлении, для magnet-ссылки —
  /// собранное из пришедших метаданных. Пока метаданные не пришли, отдавать
  /// нечего: раздача известна только по хешу.
  String? torrentPathFor(String id) => _downloads[id]?.torrentPath;

  /// Поднимает задачу: для magnet сначала качаются метаданные.
  Future<void> _launch(_ManagedDownload managed) async {
    final generation = managed.generation;
    try {
      managed.error = null;
      var model = managed.model;

      // Файл могли удалить у нас за спиной — тогда остаётся magnet-ссылка.
      if (model == null &&
          managed.torrentPath != null &&
          await File(managed.torrentPath!).exists()) {
        model = await parseTorrent(managed.torrentPath!);
      }
      model ??= await managed.fetchMetadata();
      if (model == null ||
          generation != managed.generation ||
          managed.pausedByUser ||
          !managed.started) {
        return;
      }

      managed.model = model;
      managed.name = model.name;

      final task = dt.TorrentTask.newTask(
        model,
        managed.savePath,
        false,
        null,
        null,
        null,
        buildProxyConfig(),
      );
      managed.task = task;
      await task.start();
      // Ограничение задаётся задаче, а не движку целиком, поэтому новую
      // нужно догнать текущими настройками.
      _limitTask(task);
    } on Object catch (error) {
      if (generation == managed.generation) {
        managed.error = error.toString();
      }
    }
  }

  /// Останавливает раздачу, когда заданный рейтинг достигнут.
  ///
  /// Проверяем при каждом опросе, а не по событию: движок о рейтинге ничего
  /// не знает, а отданное растёт постепенно. Остановленную задачу очередь
  /// больше не поднимает — для неё это выглядит как пауза от пользователя.
  void _stopSeedingIfDone(_ManagedDownload managed, DownloadTask task) {
    if (managed.pausedByUser || task.state != DownloadState.complete) return;
    if (!_limits.seedingDone(
      uploaded: task.uploadedBytes,
      downloaded: task.completedBytes,
    )) {
      return;
    }
    managed.pausedByUser = true;
    managed.started = false;
    // pause() у движка синхронный, оборачивать его не во что.
    managed.task?.pause();
    unawaited(_persist());
  }

  /// Действующие ограничения и то, идёт ли игра.
  SpeedLimits _limits = SpeedLimits.unlimited;
  bool _playing = false;

  @visibleForTesting
  SpeedLimits get appliedLimits => _limits;

  @override
  Future<void> applyLimits(SpeedLimits limits, {required bool playing}) async {
    if (limits == _limits && playing == _playing) return;
    _limits = limits;
    _playing = playing;
    for (final managed in _downloads.values) {
      final task = managed.task;
      if (task != null) _limitTask(task);
    }
  }

  /// Публичного способа задать предел разом у движка нет — есть окно
  /// расписания у задачи. Ставим одно окно на все дни и все сутки:
  /// расписанием мы не пользуемся, нужен только предел скорости.
  void _limitTask(dt.TorrentTask task) {
    final download = _limits.downloadBytes(playing: _playing);
    final upload = _limits.uploadBytes;
    if (download == null && upload == null) {
      task.removeScheduleWindow(_limitWindowId);
      return;
    }
    task.addScheduleWindow(
      dt.ScheduleWindow(
        id: _limitWindowId,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        start: Duration.zero,
        end: const Duration(hours: 23, minutes: 59),
        maxDownloadRate: download,
        maxUploadRate: upload,
        // Иначе вне окна задача встала бы на паузу — а окно у нас
        // круглосуточное только по недосмотру расписания.
        pauseOutsideWindow: false,
      ),
    );
  }

  static const _limitWindowId = 'evaporate-speed-limit';

  /// Открыто для тестов: настройки прокси приложения в конфиг движка.
  @visibleForTesting
  dt.ProxyConfig? buildProxyConfig() {
    if (!_proxy.isUsable) return null;
    final host = _proxy.host.trim().replaceFirst(RegExp(r'^\w+://'), '');
    final user = _proxy.hasCredentials ? _proxy.username : null;
    final password = _proxy.password.isEmpty ? null : _proxy.password;

    return switch (_proxy.kind) {
      // Для SOCKS5 прокси покрывает и пиров — ради этого движок и менялся.
      ProxyKind.socks5 => dt.ProxyConfig.socks5(
        host: host,
        port: _proxy.port,
        username: user,
        password: password,
        useForTrackers: true,
        useForPeers: true,
      ),
      ProxyKind.http => dt.ProxyConfig.http(
        host: host,
        port: _proxy.port,
        username: user,
        password: password,
      ),
    };
  }

  // ------------------------------------------------------------ управление

  @override
  Future<void> pause(String id) async {
    final managed = _downloads[id];
    if (managed == null) return;
    managed.pausedByUser = true;
    if (managed.task == null) {
      await managed.dispose();
    } else {
      managed.task!.pause();
      managed.started = false;
    }
    await _persist();
    // Освободившийся слот отдаём тому, кто ждёт очереди.
    pumpQueue();
    await refresh();
  }

  @override
  Future<void> resume(String id) async {
    final managed = _downloads[id];
    if (managed == null) return;
    managed.pausedByUser = false;
    managed.started = false;
    pumpQueue();
    await _persist();
    await refresh();
  }

  @override
  Future<void> remove(String id) async {
    final managed = _downloads.remove(id);
    _order.remove(id);
    await managed?.dispose();
    await _persist();
    pumpQueue();
    await refresh();
  }

  @override
  DownloadTask? taskById(String id) {
    for (final task in _tasks.value) {
      if (task.id == id) return task;
    }
    return null;
  }

  @override
  Future<void> refresh() async {
    final snapshot = <DownloadTask>[];
    var download = 0;
    var upload = 0;
    var active = 0;

    for (final managed in _ordered) {
      final task = managed.toDownloadTask();
      snapshot.add(task);
      download += task.downloadSpeed;
      upload += task.uploadSpeed;
      if (task.isRunning) active++;
      _stopSeedingIfDone(managed, task);
    }

    _tasks.value = snapshot;
    _stats.value = EngineStats(
      downloadSpeed: download,
      uploadSpeed: upload,
      activeCount: active,
      waitingCount: snapshot.length - active,
    );
  }

  /// Проверяет, что скачанное действительно лежит на диске целиком.
  ///
  /// Хеши кусков BitTorrent сверяет ещё при скачивании — битые данные просто
  /// не принимаются. А вот пропавший или обрезанный файл протокол уже не
  /// заметит: именно это здесь и ищем.
  Future<IntegrityReport> verify(String id) async {
    final managed = _downloads[id];
    final model = managed?.model;
    if (managed == null || model == null) {
      return const IntegrityReport.skipped();
    }

    return checkFiles(
      root: managed.savePath,
      expected: [
        for (final file in model.files) (path: file.path, length: file.length),
      ],
    );
  }

  /// Открыто для тестов: настоящий торрент для проверки не нужен.
  @visibleForTesting
  static Future<IntegrityReport> checkFiles({
    required String root,
    required List<({String path, int length})> expected,
  }) async {
    final missing = <String>[];
    final truncated = <String>[];

    for (final entry in expected) {
      final file = File(p.join(root, entry.path));
      if (!await file.exists()) {
        missing.add(entry.path);
        continue;
      }
      if (await file.length() < entry.length) truncated.add(entry.path);
    }

    return IntegrityReport(
      checkedFiles: expected.length,
      missing: missing,
      truncated: truncated,
    );
  }

  // --------------------------------------------------------- сохранение

  Future<void> _persist() async {
    await _store.write({
      'version': 1,
      'downloads': _ordered.map((d) => d.toJson()).toList(),
    });
  }

  /// Список загрузок переживает перезапуск приложения: своего файла сессии
  /// у библиотеки нет, поэтому ведём его сами.
  Future<void> _restoreState() async {
    final restored = await _store.readAs((json) {
      final entries = json['downloads'] as List<dynamic>? ?? const [];
      return entries
          .map(
            (entry) =>
                _ManagedDownload.fromJson(entry as Map<String, dynamic>, this),
          )
          .toList();
    });
    for (final managed in restored ?? <_ManagedDownload>[]) {
      _register(managed);
    }
    pumpQueue();
  }

  static String _hex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  void dispose() {
    _pollTimer?.cancel();
    for (final managed in _downloads.values) {
      unawaited(managed.dispose());
    }
    _status.dispose();
    _tasks.dispose();
    _stats.dispose();
  }
}

/// Одна загрузка: задача движка плюс то, что нужно её восстановить.
class _ManagedDownload {
  _ManagedDownload({
    required this.infoHash,
    required this.savePath,
    required this.name,
    required this.engine,
    this.magnet,
    this.torrentPath,
  });

  final String infoHash;
  final String savePath;
  final DtorrentEngine engine;
  final String? magnet;

  /// Файл раздачи. У magnet-ссылки его сначала нет, но после получения
  /// метаданных появляется: собранный `.torrent` сохраняется на диск, и
  /// дальше задача поднимается из него, а не из сети.
  String? torrentPath;

  String name;

  /// Задача заняла слот очереди (уже запущена или запускается).
  bool started = false;

  /// Пауза именно от пользователя — такую задачу очередь не трогает.
  bool pausedByUser = false;
  int generation = 0;
  Completer<dt.TorrentModel?>? _metadataResult;
  dt.TorrentModel? model;
  dt.TorrentTask? task;
  dt.MetadataDownloader? metadata;
  String? error;

  /// Метаданные magnet-ссылки: пока они не скачаны, задача видна в списке
  /// как «Получение метаданных», а не пропадает из интерфейса.
  bool get isFetchingMetadata => model == null && error == null;

  Future<dt.TorrentModel?> fetchMetadata() async {
    final link = magnet;
    if (link == null) return null;

    final parsed = dt.MagnetParser.parse(link);
    final downloader = dt.MetadataDownloader(
      infoHash,
      trackers: parsed?.trackers,
    );
    metadata = downloader;

    final completer = Completer<dt.TorrentModel?>();
    _metadataResult = completer;
    downloader.events.listen((event) {
      if (completer.isCompleted) return;
      if (event is dt.MetaDataDownloadComplete) {
        try {
          completer.complete(
            _adoptMetadata(
              Uint8List.fromList(event.data),
              parsed?.trackers ?? const [],
            ),
          );
        } on Object catch (error) {
          completer.completeError(error);
        }
      } else if (event is dt.MetaDataDownloadFailed) {
        completer.complete(null);
      }
    });

    await downloader.startDownload();
    return completer.future;
  }

  /// По magnet-ссылке приходит голый info-словарь, а не файл раздачи:
  /// разборщику нужен торрент целиком, поэтому словарь заворачиваем в него
  /// сами. Трекеры при этом переезжают из ссылки в файл — иначе задача
  /// осталась бы с одним DHT, хотя пользователь дал ей адреса.
  ///
  /// Готовый файл сохраняем: метаданные ищутся в сети минутами, и платить
  /// за это при каждом запуске приложения незачем. Он же уходит на экспорт.
  Future<dt.TorrentModel> _adoptMetadata(
    Uint8List infoDict,
    List<Uri> trackers,
  ) async {
    final bytes = TorrentFile.assemble(infoDict, trackers: trackers);
    final model = DtorrentEngine.torrentFromBytes(bytes);
    try {
      final file = File(p.join(engine.torrentsDir, '$infoHash.torrent'));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      torrentPath = file.path;
      await engine._persist();
    } on Object {
      // Не записался — раздача от этого не страдает, просто метаданные
      // придётся искать заново.
    }
    return model;
  }

  DownloadTask toDownloadTask() {
    final current = task;
    final total = _totalBytes();
    final completed = current?.downloaded ?? 0;

    return DownloadTask(
      id: infoHash,
      name: name,
      state: _state(),
      totalBytes: total,
      completedBytes: completed,
      downloadSpeed: (current?.currentDownloadSpeed ?? 0).round(),
      uploadSpeed: (current?.uploadSpeed ?? 0).round(),
      // Движок ведёт счёт отданного в файле состояния — он переживает
      // перезапуск, в отличие от накопленного в памяти.
      uploadedBytes: current?.stateFile?.uploaded ?? 0,
      connections: current?.connectedPeersNumber ?? 0,
      seeders: current?.seederNumber ?? 0,
      dir: savePath,
      files: model == null
          ? const []
          : model!.files.map((f) => p.join(savePath, f.path)).toList(),
      errorMessage: error,
      isMetadata: isFetchingMetadata,
      infoHash: infoHash,
      isQueued: !started && !pausedByUser,
    );
  }

  int _totalBytes() {
    final info = model;
    if (info == null) return 0;
    return info.length ??
        info.files.fold<int>(0, (sum, file) => sum + file.length);
  }

  DownloadState _state() {
    if (error != null) return DownloadState.error;
    if (pausedByUser) return DownloadState.paused;
    final current = task;
    if (current == null) return DownloadState.waiting;
    if ((current.progress) >= 1.0) return DownloadState.complete;
    return switch (current.state) {
      dt.TaskState.running => DownloadState.active,
      dt.TaskState.paused => DownloadState.paused,
      dt.TaskState.stopped => DownloadState.waiting,
    };
  }

  Map<String, dynamic> toJson() => {
    'infoHash': infoHash,
    'savePath': savePath,
    'name': name,
    if (magnet != null) 'magnet': magnet,
    if (torrentPath != null) 'torrentPath': torrentPath,
    if (pausedByUser) 'pausedByUser': true,
  };

  factory _ManagedDownload.fromJson(
    Map<String, dynamic> json,
    DtorrentEngine engine,
  ) {
    final managed = _ManagedDownload(
      infoHash: json['infoHash'] as String,
      savePath: json['savePath'] as String,
      name: json['name'] as String? ?? 'Torrent',
      magnet: json['magnet'] as String?,
      torrentPath: json['torrentPath'] as String?,
      engine: engine,
    );
    managed.pausedByUser = json['pausedByUser'] as bool? ?? false;
    return managed;
  }

  Future<void> dispose() async {
    generation++;
    final result = _metadataResult;
    if (result != null && !result.isCompleted) result.complete(null);
    _metadataResult = null;
    try {
      await metadata?.stop();
      await task?.stop();
      await task?.dispose();
    } on Object {
      // Задача могла не запуститься — гасим тихо.
    }
    task = null;
    metadata = null;
    started = false;
  }
}

/// Кодирование JSON вынесено сюда, чтобы файл состояния читался глазами.
String encodeState(Map<String, dynamic> data) =>
    const JsonEncoder.withIndent('  ').convert(data);
