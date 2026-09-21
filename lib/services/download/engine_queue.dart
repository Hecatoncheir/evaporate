part of 'dtorrent_engine.dart';

/// Очередь загрузок: кто следующий, сколько занято слотов и как задача
/// поднимается, когда слот ей достался.
///
/// Карта загрузок и порядок в ней остались полями движка: расширение
/// полей не заводит. Само расширение не приватное — `positionOf` зовут
/// снаружи, а члены приватного расширения за пределы библиотеки не видны.
/// `pumpQueue` и `reorder` по той же причине переехали **в класс**: они
/// часть контракта [DownloadEngine], а членами интерфейса расширения не
/// бывают.
extension EngineQueue on DtorrentEngine {
  void _register(_ManagedDownload managed) {
    _downloads[managed.infoHash] = managed;
    _queue.add(managed.infoHash);
  }

  /// Позиция в очереди — её показывает интерфейс.
  int positionOf(String id) => _queue.positionOf(id);

  /// Поднимает задачу: для magnet сначала качаются метаданные.
  Future<void> _launch(_ManagedDownload managed) async {
    final generation = managed.generation;
    try {
      final model = await _modelFor(managed);
      if (!_stillWanted(managed, generation)) return;
      // Метаданные не пришли — это ошибка со словами, а не тихий выход:
      // иначе задача навсегда оставалась бы «получающей метаданные» и
      // держала слот очереди.
      if (model == null) {
        await _fail(managed, _l.metadataNotFound);
        return;
      }
      await _startTask(managed, model);
    } on Object catch (error) {
      if (generation == managed.generation) {
        await _fail(managed, error.toString());
      }
    }
  }

  /// Нужно ли ещё то, чего мы дождались.
  ///
  /// Метаданные идут из сети и приходят через минуты. За это время задачу
  /// могли поставить на паузу, снять или поднять заново — а снятие
  /// увеличивает поколение, и дождавшийся ответ принадлежит прошлой жизни
  /// задачи, а не нынешней.
  bool _stillWanted(_ManagedDownload managed, int generation) =>
      generation == managed.generation && managed.isActive;

  /// Поднимает задачу движка по готовой модели раздачи.
  Future<void> _startTask(
    _ManagedDownload managed,
    dt.TorrentModel model,
  ) async {
    managed.model = model;
    managed.name = model.name;

    final task = dt.TorrentTask.newTask(
      _announcingThroughProxy(model),
      managed.savePath,
      false,
      null,
      null,
      null,
      torrentProxyConfig(_proxy),
    );
    managed.task = task;
    await task.start();
  }

  /// Модель для задачи — без трекеров, до которых прокси не дотянется
  /// (`announcesFor`). У задачи остаётся исходная модель: файл раздачи на
  /// выгрузку уходит целым, со всеми трекерами.
  dt.TorrentModel _announcingThroughProxy(dt.TorrentModel model) {
    final announces = announcesFor(model.announces, _proxy);
    if (announces.length == model.announces.length) return model;
    return dt.TorrentModel(
      name: model.name,
      files: model.files,
      infoHashBuffer: model.infoHashBuffer,
      pieceLength: model.pieceLength,
      pieces: model.pieces,
      announces: announces,
      nodes: model.nodes,
      length: model.length,
      version: model.version,
      metaVersion: model.metaVersion,
      fileTree: model.fileTree,
      pieceLayers: model.pieceLayers,
      rootHash: model.rootHash,
      infoDictBytes: model.infoDictBytes,
      rawData: model.rawData,
    );
  }

  /// Файл раздачи, если он есть, иначе метаданные из сети.
  Future<dt.TorrentModel?> _modelFor(_ManagedDownload managed) async {
    final known = managed.model;
    if (known != null) return known;
    // Файл могли удалить у нас за спиной — тогда остаётся magnet-ссылка.
    final path = managed.torrentPath;
    if (path != null && await File(path).exists()) {
      return TorrentSource.fromFile(path);
    }
    // Искать по сети при SOCKS5 значит пойти к пирам мимо него:
    // поиск метаданных в библиотеке прокси не знает.
    if (!canFetchMetadata(_proxy)) {
      throw DownloadEngineException(_l.magnetNeedsTorrentBehindProxy);
    }
    final fetch = _fetchMetadata;
    final found = fetch != null
        ? fetch(managed.infoHash)
        : managed.fetchMetadata();
    // Не дождались — «не найдено»: `_launch` сорвёт задачу словами, и слот
    // уйдёт следующей.
    return found.timeout(metadataTimeout, onTimeout: () => null);
  }

  /// Задача сорвалась: она уступает слот следующей, а ошибку снимает
  /// «Возобновить».
  ///
  /// Прежде ошибка оставляла задачу занимающей слот: очередь её обходила,
  /// но считала запущенной, и три сорвавшиеся задачи при пределе в три
  /// запирали очередь до перезапуска приложения.
  Future<void> _fail(_ManagedDownload managed, String message) async {
    await managed.dispose();
    managed.markFailed(message);
    pumpQueue();
  }
}
