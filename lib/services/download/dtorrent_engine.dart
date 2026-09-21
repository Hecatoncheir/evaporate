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
import 'download_queue.dart';
import 'integrity_check.dart';
import 'torrent_file.dart';
import 'torrent_source.dart';
import 'torrent_task_options.dart';

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
    this.metadataTimeout = const Duration(minutes: 10),
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

  @override
  String downloadDir;

  /// Куда складывать `.torrent` раздач. Magnet-ссылка приносит метаданные
  /// один раз и из сети; сохранённый файл избавляет от повторного их поиска
  /// после перезапуска — и его же потом отдают на экспорт.
  final String torrentsDir;

  /// Сколько задач качается одновременно; остальные ждут очереди.
  @override
  int maxConcurrent;

  /// В тестах выключается, чтобы движок не лез в сеть: очередь и состояние
  /// проверяются без единого соединения.
  final bool autoStart;

  /// Сколько ждать описание раздачи по magnet-ссылке.
  ///
  /// Библиотека отказ шлёт только после трёх несовпадений хеша, а при
  /// полном отсутствии пиров — никогда: задача навсегда оставалась
  /// «получающей метаданные» и держала слот. Десяти минут хватает живой
  /// раздаче с медленным DHT; дольше — уже не ожидание, а зависание.
  final Duration metadataTimeout;

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

  /// Порядок задач и раздача слотов: правила очереди живут отдельно от
  /// работы с раздачами и проверяются на одних идентификаторах.
  final _queue = DownloadQueue();

  /// Кто занял слоты очереди. Открыто для тестов: иначе очередь пришлось бы
  /// проверять по сетевым эффектам.
  @visibleForTesting
  Set<String> get startedIds =>
      _downloads.values.where((d) => d.isActive).map((d) => d.infoHash).toSet();
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
  @override
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
    _queue.clear();
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
      torrentsDir: torrentsDir,
      onChanged: _persist,
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
      torrentsDir: torrentsDir,
      onChanged: _persist,
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
  @override
  String? torrentPathFor(String id) => _downloads[id]?.torrentPath;

  /// Действующие ограничения: из них работает рейтинг раздачи.
  SpeedLimits _limits = SpeedLimits.unlimited;

  @visibleForTesting
  SpeedLimits get appliedLimits => _limits;

  /// Запоминает пределы, но задачам их не ставит.
  ///
  /// Предел скорости `dtorrent_task_v2` принимает только окном расписания,
  /// а скорость из окна кладёт в поле, которое сама не читает нигде: предел
  /// не действует вовсе. Зато постановка окна зовёт `resumeTask` — и
  /// поставленные на паузу задачи начинали качать на полную, пока
  /// интерфейс показывал «Пауза»: достаточно было запустить игру при
  /// заданном пределе на время игры. Вернуть сюда окно можно только вместе
  /// с правкой форка, которая научит его ограничивать; до тех пор подпись
  /// в настройках говорит, что предел не действует. Рейтинг раздачи
  /// считаем сами (`_stopSeedingIfDone`), и он работает.
  @override
  Future<void> applyLimits(SpeedLimits limits, {required bool playing}) async {
    _limits = limits;
  }

  /// Куда переходит слот задачи по её состоянию.
  ///
  /// Скачавшаяся из «идёт» уходит в «раздаёт» и слот освобождает: иначе при
  /// трёх слотах и раздаче «вечно» три готовые игры запирали очередь
  /// навсегда. Прочие переходы решают нажатия человека и отказы, а не опрос.
  @visibleForTesting
  static SlotState slotAfter(SlotState slot, DownloadState state) =>
      slot == SlotState.running && state == DownloadState.complete
      ? SlotState.seeding
      : slot;

  /// Останавливает раздачу, когда заданный рейтинг достигнут.
  ///
  /// Проверяем при каждом опросе, а не по событию: движок о рейтинге ничего
  /// не знает, а отданное растёт постепенно. Остановленную задачу очередь
  /// больше не поднимает — для неё это выглядит как пауза от пользователя.
  void _stopSeedingIfDone(_ManagedDownload managed, DownloadTask task) {
    if (!managed.isSeeding || task.state != DownloadState.complete) return;
    final done = _limits.seedingDone(
      uploaded: task.uploadedBytes,
      downloaded: task.completedBytes,
    );
    if (!done) return;
    managed.markPaused();
    // pause() у движка синхронный, оборачивать его не во что.
    managed.task?.pause();
    unawaited(_persist());
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

  // ------------------------------------------------------------ управление

  @override
  Future<void> pause(String id) async {
    final managed = _downloads[id];
    if (managed == null) return;
    managed.markPaused();
    if (managed.task == null) {
      await managed.dispose();
    } else {
      managed.task!.pause();
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
    // «Возобновить» у сорвавшейся задачи — это «попробовать снова»: без
    // снятия ошибки очередь обходила бы её до перезапуска приложения.
    managed.markWaiting();
    pumpQueue();
    await _persist();
    await refresh();
  }

  @override
  Future<void> remove(String id) async {
    final managed = _downloads.remove(id);
    _queue.remove(id);
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
    var freed = false;

    for (final managed in _ordered) {
      final task = managed.toDownloadTask();
      snapshot.add(task);
      download += task.downloadSpeed;
      upload += task.uploadSpeed;
      if (task.isRunning) active++;
      final next = slotAfter(managed.slot, task.state);
      if (next != managed.slot) {
        managed.markSeeding();
        freed = true;
      }
      _stopSeedingIfDone(managed, task);
    }
    // Скачавшаяся уступила слот — отдаём его следующей сразу, а не к
    // следующему добавлению.
    if (freed) pumpQueue();

    _tasks.value = snapshot;
    _stats.value = EngineStats(
      downloadSpeed: download,
      uploadSpeed: upload,
      activeCount: active,
      waitingCount: snapshot.length - active,
    );
  }

  /// Задачи в порядке очереди — те, что ещё живы.
  Iterable<_ManagedDownload> get _ordered sync* {
    for (final id in _queue.ids) {
      final managed = _downloads[id];
      if (managed != null) yield managed;
    }
  }

  /// Запускает ожидающие задачи, пока есть свободные слоты.
  ///
  /// Зовут и снаружи: при смене числа одновременных загрузок
  /// освободившиеся слоты нужно раздать сразу.
  @override
  void pumpQueue() {
    final starting = _queue.readyToStart(
      slots: maxConcurrent,
      isActive: (id) => _downloads[id]?.isActive ?? false,
      isWaiting: (id) => _downloads[id]?.isWaiting ?? false,
    );
    for (final id in starting.toList()) {
      final managed = _downloads[id]!;
      managed.markRunning();
      if (!autoStart) continue;
      if (managed.task != null) {
        managed.task!.resume();
      } else {
        unawaited(_launch(managed));
      }
    }
  }

  /// Переставляет задачу в очереди. Уже запущенные задачи не трогаем:
  /// перезапуск ради порядка рвал бы соединения с пирами.
  @override
  Future<void> reorder(String id, int newIndex) async {
    if (!_queue.moveTo(id, newIndex)) return;
    await _persist();
    pumpQueue();
    await refresh();
  }

  /// Проверяет, что скачанное действительно лежит на диске целиком.
  ///
  /// Хеши кусков BitTorrent сверяет ещё при скачивании — битые данные просто
  /// не принимаются. А вот пропавший или обрезанный файл протокол уже не
  /// заметит: именно это здесь и ищем.
  @override
  Future<IntegrityReport> verify(String id) async {
    final managed = _downloads[id];
    final model = managed?.model;
    if (managed == null || model == null) {
      return const IntegrityReport.skipped();
    }

    return IntegrityCheck.run(
      root: managed.savePath,
      expected: expectedOnDisk(model.files),
    );
  }

  /// Какие файлы раздачи обязаны лежать на диске.
  ///
  /// Заполнители выравнивания (BEP 47, `_____padding_file_N_____`) библиотека
  /// держит виртуальными, а ссылки создаёт ссылками — ни у тех, ни у
  /// других на диске нет файла той длины, что записана в раздаче. Проверка
  /// считала их пропавшими, и скачанная целиком раздача навсегда
  /// оставалась «с ошибкой».
  @visibleForTesting
  static List<({String path, int length})> expectedOnDisk(
    Iterable<dt.TorrentFileModel> files,
  ) => [
    for (final file in files)
      if (!file.isPaddingFile && (file.symlinkPath?.isEmpty ?? true))
        (path: file.path, length: file.length),
  ];

  @override
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
