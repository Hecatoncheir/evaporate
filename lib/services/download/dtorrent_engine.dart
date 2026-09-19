import 'dart:async';
import 'dart:io';

import 'package:dtorrent_task_v2/dtorrent_task_v2.dart' as dt;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/json_store.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';
import '../../models/download_task.dart';
import '../../models/proxy_settings.dart';
import '../../models/speed_limits.dart';
import '../system/app_log.dart';
import 'download_engine.dart';
import 'integrity_check.dart';
import 'torrent_file.dart';
import 'torrent_source.dart';

part 'engine_limits.dart';
part 'engine_queue.dart';
part 'engine_store.dart';
part 'managed_download.dart';

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
    @visibleForTesting this._fetchMetadata,
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

  /// Получение метаданных вместо сети — для тестов запуска задачи.
  final Future<dt.TorrentModel?> Function(String infoHash)? _fetchMetadata;
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

  /// Кто занял слоты очереди. Открыто для тестов: иначе очередь пришлось бы
  /// проверять по сетевым эффектам.
  @visibleForTesting
  Set<String> get startedIds =>
      _downloads.values.where((d) => d.started).map((d) => d.infoHash).toSet();
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
      model = await TorrentSource.fromFile(path);
    } on UnsafeTorrentException catch (error) {
      throw DownloadEngineException(_l.torrentUnsafePath(error.path));
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

  /// Infohash magnet-ссылки в том виде, в каком его знают все остальные:
  /// строкой шестнадцатеричных цифр. Она же служит движку идентификатором
  /// задачи.
  static String _hex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// Файл раздачи, если движок им располагает.
  ///
  /// Для торрента это то, что дали при добавлении, для magnet-ссылки —
  /// собранное из пришедших метаданных. Пока метаданные не пришли, отдавать
  /// нечего: раздача известна только по хешу.
  String? torrentPathFor(String id) => _downloads[id]?.torrentPath;

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

  /// Во что складывается состояние задачи.
  ///
  /// Порядок проверок и есть суть. **Готовность решается раньше паузы**:
  /// скачанное остаётся скачанным, остановили раздачу или нет, — а
  /// остановить её может и сам движок, дойдя до заданного предела рейтинга.
  /// Пока пауза шла первой, законченная загрузка так и не объявлялась
  /// законченной: игра не становилась установленной, кнопка «Играть» не
  /// появлялась, а на её месте оставались «Пауза» и «Отменить».
  ///
  /// Байты считаем сами, а не спрашиваем у движка `progress`: тот делит
  /// скачанное на `length` из метаданных, а `length` есть только у
  /// однофайловой раздачи. У игры из дюжины файлов он `null`, и готовность
  /// у движка всегда ноль — «завершено» не наступало никогда, игра не
  /// становилась установленной, и запустить скачанное было нечем.
  ///
  /// Открыто для тестов: порядок важнее всего остального в этом файле, а
  /// проверить его можно без движка и без сети.
  @visibleForTesting
  static DownloadState stateOf({
    required bool hasError,
    required bool pausedByUser,
    required int completedBytes,
    required int totalBytes,
    required dt.TaskState? taskState,
  }) {
    if (hasError) return DownloadState.error;
    // Задачи ещё нет — она ждёт своей очереди. Пауза здесь всё же вперёд:
    // о готовности сказать нечего, скачанного не существует.
    if (taskState == null) {
      return pausedByUser ? DownloadState.paused : DownloadState.waiting;
    }
    if (totalBytes > 0 && completedBytes >= totalBytes) {
      return DownloadState.complete;
    }
    if (pausedByUser) return DownloadState.paused;
    return switch (taskState) {
      dt.TaskState.running => DownloadState.active,
      dt.TaskState.paused => DownloadState.paused,
      dt.TaskState.stopped => DownloadState.waiting,
    };
  }

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
    // «Возобновить» у сорвавшейся задачи — это «попробовать снова»: без
    // снятия ошибки очередь обходила бы её до перезапуска приложения.
    managed.error = null;
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

    return IntegrityCheck.run(
      root: managed.savePath,
      expected: [
        for (final file in model.files) (path: file.path, length: file.length),
      ],
    );
  }

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
