part of 'dtorrent_engine.dart';

/// Очередь загрузок: кто следующий, сколько занято слотов и как задача
/// поднимается, когда слот ей достался.
///
/// Карта загрузок и порядок в ней остались полями движка: расширение
/// полей не заводит. Само расширение не приватное — `pumpQueue`,
/// `reorder` и `positionOf` зовут снаружи, а члены приватного расширения
/// за пределы библиотеки не видны — сколько их ни импортируй.
extension EngineQueue on DtorrentEngine {
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
    final generation = managed.generation;
    bool stillWanted() =>
        generation == managed.generation &&
        !managed.pausedByUser &&
        managed.started;
    try {
      managed.error = null;
      final model = await _modelFor(managed);
      if (!stillWanted()) return;
      // Метаданные не пришли — это ошибка со словами, а не тихий выход:
      // иначе задача навсегда оставалась бы «получающей метаданные» и
      // держала слот очереди.
      if (model == null) {
        await _fail(managed, _l.metadataNotFound);
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
        await _fail(managed, error.toString());
      }
    }
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
    final fetch = _fetchMetadata;
    return fetch != null ? fetch(managed.infoHash) : managed.fetchMetadata();
  }

  /// Задача сорвалась: она уступает слот следующей, а ошибку снимает
  /// «Возобновить».
  ///
  /// Прежде ошибка оставляла задачу занимающей слот: очередь её обходила,
  /// но считала запущенной, и три сорвавшиеся задачи при пределе в три
  /// запирали очередь до перезапуска приложения.
  Future<void> _fail(_ManagedDownload managed, String message) async {
    await managed.dispose();
    managed.error = message;
    pumpQueue();
  }
}
