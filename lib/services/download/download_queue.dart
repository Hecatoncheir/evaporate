/// Порядок задач и раздача слотов.
///
/// Отдельно от движка, потому что это правила очереди, а не работа с
/// раздачами: кто раньше, кто позже, сколько может идти разом и кто
/// занимает слот. Проверить их можно на одних идентификаторах — ни сети,
/// ни диска для этого не нужно, а прежде они жили в цикле подъёма задач и
/// проверялись только живой загрузкой.
class DownloadQueue {
  final List<String> _order = [];

  /// Задачи в порядке очереди.
  List<String> get ids => List.unmodifiable(_order);

  /// Ставит задачу в конец, если её там ещё нет.
  ///
  /// Повторное добавление порядок не меняет: задачу могли поднять заново
  /// после перезапуска движка, и её место в очереди — то же самое.
  void add(String id) {
    if (!_order.contains(id)) _order.add(id);
  }

  void remove(String id) => _order.remove(id);

  void clear() => _order.clear();

  /// Позиция в очереди — её показывает интерфейс. `-1` — задачи нет.
  int positionOf(String id) => _order.indexOf(id);

  /// Переставляет задачу на [index]. `false` — переставлять нечего.
  ///
  /// Номер зажимается в границы: он приходит из интерфейса, где список
  /// мог измениться между нажатием и обработкой.
  bool moveTo(String id, int index) {
    final from = _order.indexOf(id);
    if (from == -1) return false;
    final target = index.clamp(0, _order.length - 1);
    if (from == target) return false;

    _order.removeAt(from);
    _order.insert(target, id);
    return true;
  }

  /// Кого поднимать прямо сейчас.
  ///
  /// Идём по порядку и раздаём свободные слоты ждущим. Занятые слоты
  /// считаются до раздачи и растут по мере её: иначе очередь при пределе
  /// в три поднимала бы сразу всех.
  ///
  /// Остановленные человеком и сорвавшиеся слота не занимают и не ждут:
  /// первых он остановил сам, а вторых поднимет «Возобновить». Прежде
  /// сорвавшаяся задача держала слот, и три такие запирали очередь до
  /// перезапуска приложения.
  Iterable<String> readyToStart({
    required int slots,
    required bool Function(String id) isActive,
    required bool Function(String id) isWaiting,
  }) sync* {
    var busy = _order.where(isActive).length;
    for (final id in _order) {
      if (busy >= slots) return;
      if (!isWaiting(id)) continue;
      busy++;
      yield id;
    }
  }
}
