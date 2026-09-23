part of 'dtorrent_engine.dart';

/// Где задача в очереди: ждёт слота, идёт, раздаёт, остановлена или
/// сорвалась.
///
/// Раздача — своё состояние, а не «идёт»: готовая задача слота не держит.
/// Прежде держала, и при трёх слотах и раздаче «вечно» (оба — значения по
/// умолчанию) три скачанные игры запирали очередь навсегда, а строка
/// состояния при этом показывала «0 / 3» — интерфейс готовые не считал.
enum SlotState { waiting, running, seeding, paused, failed }

/// Одна загрузка: задача движка плюс то, что нужно её восстановить.
class _ManagedDownload {
  _ManagedDownload({
    required this.infoHash,
    required this.savePath,
    required this.name,
    required this.torrentsDir,
    required this.onChanged,
    this.magnet,
    this.torrentPath,
  });

  final String infoHash;
  final String savePath;

  /// Куда класть файл раздачи, собранный из метаданных magnet-ссылки.
  final String torrentsDir;

  /// Чем сказать, что список задач изменился и его пора записать.
  ///
  /// Обратным вызовом, а не ссылкой на движок: задаче от него нужны были
  /// ровно две вещи — папка и «запиши», — а знала она его целиком.
  final Future<void> Function() onChanged;

  final String? magnet;

  /// Файл раздачи. У magnet-ссылки его сначала нет, но после получения
  /// метаданных появляется: собранный `.torrent` сохраняется на диск, и
  /// дальше задача поднимается из него, а не из сети.
  String? torrentPath;

  String name;

  /// Где задача в очереди.
  ///
  /// Одним полем, а не тремя флагами: прежде «занимает слот» и «ждёт
  /// слота» приходилось складывать из `started`, `pausedByUser` и
  /// `error`, правились они в шести местах, и забытое присваивание
  /// оставляло задачу в состоянии, которого не бывает, — запущенной и
  /// сорвавшейся разом.
  SlotState slot = SlotState.waiting;

  /// Занимает слот очереди.
  bool get isActive => slot == SlotState.running;

  /// Ждёт слота. Остановленная и сорвавшаяся не ждут: первую остановили
  /// сами, вторую поднимет «Возобновить».
  bool get isWaiting => slot == SlotState.waiting;

  /// Скачана и раздаёт — слота не занимает.
  bool get isSeeding => slot == SlotState.seeding;

  /// Скачалась: слот уступает следующей, а раздача идёт дальше.
  void markSeeding() => slot = SlotState.seeding;

  /// Слот занят: задача поднимается или уже идёт.
  ///
  /// Прежнюю ошибку снимаем здесь: «идёт» и «сорвалась» — разные
  /// состояния, и оставить сообщение от прошлой попытки значило бы
  /// показывать его у работающей загрузки.
  void markRunning() {
    slot = SlotState.running;
    error = null;
  }

  /// Остановлена — человеком или по достигнутому рейтингу раздачи.
  /// Очередь такую не трогает.
  void markPaused() => slot = SlotState.paused;

  /// Снова в очереди. Ошибку снимаем: «Возобновить» у сорвавшейся задачи
  /// — это «попробовать снова», а не «обойти её до перезапуска».
  void markWaiting() {
    slot = SlotState.waiting;
    error = null;
  }

  /// Сорвалась: слота не занимает и сама не поднимется.
  void markFailed(String message) {
    slot = SlotState.failed;
    error = message;
  }

  int generation = 0;
  Completer<dt.TorrentModel?>? _metadataResult;
  dt.TorrentModel? model;
  dt.TorrentTask? task;
  dt.MetadataDownloader? metadata;
  String? error;

  /// Метаданные magnet-ссылки: пока они не скачаны, задача видна в списке
  /// как «Получение метаданных», а не пропадает из интерфейса.
  bool get isFetchingMetadata => model == null && error == null;

  /// [proxy] — тот же, что у задачи: при SOCKS5 поиск ходит к пирам через
  /// него и без DHT (см. `canFetchMetadata`).
  Future<dt.TorrentModel?> fetchMetadata({dt.ProxyConfig? proxy}) async {
    final link = magnet;
    if (link == null) return null;

    final parsed = dt.MagnetParser.parse(link);
    final downloader = dt.MetadataDownloader(
      infoHash,
      trackers: parsed?.trackers,
      proxyConfig: proxy,
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
      final file = File(p.join(torrentsDir, '$infoHash.torrent'));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      torrentPath = file.path;
      await onChanged();
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
      isQueued: isWaiting,
    );
  }

  int _totalBytes() {
    final info = model;
    if (info == null) return 0;
    return info.length ??
        info.files.fold<int>(0, (sum, file) => sum + file.length);
  }

  DownloadState _state() => DtorrentEngine.stateOf(
    hasError: slot == SlotState.failed,
    pausedByUser: slot == SlotState.paused,
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
    if (slot == SlotState.paused) 'pausedByUser': true,
    // Сорвавшаяся «сама не поднимется» и после перезапуска. Без этого она
    // вставала в очередь и качалась за спиной, а игра со статусом «ошибка»
    // за такой загрузкой не следит вовсе.
    if (slot == SlotState.failed) 'failed': error ?? '',
  };

  factory _ManagedDownload.fromJson(
    Map<String, dynamic> json, {
    required String torrentsDir,
    required Future<void> Function() onChanged,
  }) {
    final managed = _ManagedDownload(
      infoHash: json['infoHash'] as String,
      savePath: json['savePath'] as String,
      name: json['name'] as String? ?? 'Torrent',
      magnet: json['magnet'] as String?,
      torrentPath: json['torrentPath'] as String?,
      torrentsDir: torrentsDir,
      onChanged: onChanged,
    );
    if (json['pausedByUser'] as bool? ?? false) managed.markPaused();
    if (json['failed'] case final String message) managed.markFailed(message);
    return managed;
  }

  /// Сколько ждать один шаг остановки. Трекер, не ответивший на прощальное
  /// объявление, не должен держать выход приложения.
  static const _stepTimeout = Duration(seconds: 2);

  /// Один шаг остановки: сбой и зависание — в журнал, остальные шаги идут.
  Future<void> _step(String what, Future<void>? Function() body) async {
    try {
      await body()?.timeout(_stepTimeout);
    } on Object catch (error) {
      // Задача могла и не запуститься; но молча не гасим — неостановленная
      // задача держит файлы и сокеты.
      AppLog.instance.write('загрузка $infoHash: $what', error);
    }
  }

  Future<void> dispose() async {
    generation++;
    final result = _metadataResult;
    if (result != null && !result.isCompleted) result.complete(null);
    _metadataResult = null;
    // Каждый шаг — отдельно и со своим пределом: прежде один `try` на три
    // шага, и сбой остановки поиска метаданных отменял остановку самой
    // задачи, а `task.stop()` ждёт объявление трекеру без всякого предела —
    // на выходе до второй задачи дело могло не дойти.
    final current = task;
    await _step('поиск метаданных', () => metadata?.stop());
    await _step('остановка', () => current?.stop());
    await _step('освобождение', () => current?.dispose());
    task = null;
    metadata = null;
    // Остановленную и сорвавшуюся не трогаем: слот они и так не
    // занимают, а их состояние человеку ещё показывают.
    if (slot == SlotState.running || slot == SlotState.seeding) {
      slot = SlotState.waiting;
    }
  }
}
