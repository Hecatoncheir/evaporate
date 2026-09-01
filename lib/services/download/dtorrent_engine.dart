import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dtorrent_task_v2/dtorrent_task_v2.dart' as dt;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/json_store.dart';
import '../../models/download_task.dart';
import '../../models/proxy_settings.dart';
import 'download_engine.dart';

/// Движок загрузок на чистом Dart поверх `dtorrent_task_v2`.
///
/// В отличие от aria2, здесь SOCKS5 применяется и к обмену с пирами, а не
/// только к трекерам — ради этого движок и выбран. Внешнего бинарника нет,
/// поэтому движок «готов» сразу после запуска.
class DtorrentEngine implements DownloadEngine {
  DtorrentEngine({
    required this.downloadDir,
    required String stateFile,
    ProxySettings proxy = const ProxySettings(),
    this.maxConcurrent = 3,
    this.autoStart = true,
  }) : _store = JsonStore(stateFile) {
    _proxy = proxy;
  }

  String downloadDir;

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
        message: 'Не удалось запустить движок: $error',
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
      unawaited(_launch(managed));
    }
  }

  // ------------------------------------------------------------ добавление

  @override
  Future<String> addMagnet(String uri, {required String dir}) async {
    final trimmed = uri.trim();
    if (!trimmed.startsWith('magnet:')) {
      throw DownloadEngineException('Это не magnet-ссылка');
    }

    final dt.MagnetLink? link;
    try {
      link = dt.MagnetParser.parse(trimmed);
    } on Object catch (error) {
      throw DownloadEngineException('Не удалось разобрать ссылку: $error');
    }
    if (link == null) {
      throw DownloadEngineException('В ссылке нет корректного infohash');
    }

    final infoHash = _hex(link.infoHash);
    if (_downloads.containsKey(infoHash)) return infoHash;

    final managed = _ManagedDownload(
      infoHash: infoHash,
      savePath: dir,
      name: link.displayName ?? 'Раздача $infoHash',
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
      throw DownloadEngineException('Файл не найден: $path');
    }

    final dt.TorrentModel model;
    try {
      model = await dt.TorrentParser.parse(path);
    } on Object catch (error) {
      throw DownloadEngineException('Не удалось прочитать торрент: $error');
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
      if (autoStart) unawaited(_launch(managed));
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

  /// Поднимает задачу: для magnet сначала качаются метаданные.
  Future<void> _launch(_ManagedDownload managed) async {
    try {
      managed.error = null;
      var model = managed.model;

      if (model == null && managed.torrentPath != null) {
        model = await dt.TorrentParser.parse(managed.torrentPath!);
      }
      model ??= await managed.fetchMetadata();
      if (model == null) return;

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
    } on Object catch (error) {
      managed.error = error.toString();
    }
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
    managed.task?.pause();
    // Освободившийся слот отдаём тому, кто ждёт очереди.
    pumpQueue();
    await refresh();
  }

  @override
  Future<void> resume(String id) async {
    final managed = _downloads[id];
    if (managed == null) return;
    managed.pausedByUser = false;
    if (managed.task != null) {
      managed.task!.resume();
    } else {
      managed.started = false;
      pumpQueue();
    }
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
    }

    _tasks.value = snapshot;
    _stats.value = EngineStats(
      downloadSpeed: download,
      uploadSpeed: upload,
      activeCount: active,
      waitingCount: snapshot.length - active,
    );
  }

  // --------------------------------------------------------- сохранение

  Future<void> _persist() async {
    await _store.write({
      'version': 1,
      'downloads': _ordered.map((d) => d.toJson()).toList(),
    });
  }

  /// Список загрузок переживает перезапуск приложения: aria2 делал это сам
  /// через файл сессии, здесь ведём его сами.
  Future<void> _restoreState() async {
    final json = await _store.read();
    final entries = json?['downloads'] as List<dynamic>? ?? const [];
    for (final entry in entries) {
      final map = entry as Map<String, dynamic>;
      final managed = _ManagedDownload.fromJson(map, this);
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
  final String? torrentPath;

  String name;

  /// Задача заняла слот очереди (уже запущена или запускается).
  bool started = false;

  /// Пауза именно от пользователя — такую задачу очередь не трогает.
  bool pausedByUser = false;
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
    downloader.events.listen((event) {
      if (completer.isCompleted) return;
      if (event is dt.MetaDataDownloadComplete) {
        try {
          completer.complete(
            dt.TorrentParser.parseBytes(Uint8List.fromList(event.data)),
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
  };

  factory _ManagedDownload.fromJson(
    Map<String, dynamic> json,
    DtorrentEngine engine,
  ) => _ManagedDownload(
    infoHash: json['infoHash'] as String,
    savePath: json['savePath'] as String,
    name: json['name'] as String? ?? 'Раздача',
    magnet: json['magnet'] as String?,
    torrentPath: json['torrentPath'] as String?,
    engine: engine,
  );

  Future<void> dispose() async {
    try {
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
