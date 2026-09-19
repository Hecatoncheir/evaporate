part of 'dtorrent_engine.dart';

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
    final model = TorrentSource.fromBytes(bytes);
    try {
      final file = File(p.join(engine.torrentsDir, '$infoHash.torrent'));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      torrentPath = file.path;
      await engine._persist();
    } on Object catch (error) {
      // Не записался — раздача от этого не страдает, просто метаданные
      // придётся искать заново.
      AppLog.instance.write('файл раздачи $infoHash не записан', error);
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
      // Сорвавшаяся задача слота не ждёт: очередь её обходит, пока её не
      // возобновят.
      isQueued: !started && !pausedByUser && error == null,
    );
  }

  int _totalBytes() {
    final info = model;
    if (info == null) return 0;
    return info.length ??
        info.files.fold<int>(0, (sum, file) => sum + file.length);
  }

  DownloadState _state() => DtorrentEngine.stateOf(
    hasError: error != null,
    pausedByUser: pausedByUser,
    completedBytes: task?.downloaded ?? 0,
    totalBytes: _totalBytes(),
    taskState: task?.state,
  );

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
