/// Прореживает отчёты о ходе долгой работы.
///
/// Кусков в загрузке приходят сотни и тысячи, а каждый отчёт — это событие
/// блока и перерисовка окна: на показ уходило больше, чем на саму загрузку,
/// и ровно от этого дёргалась анимация на фоне. Глазу довольно десятка
/// отчётов в секунду.
///
/// [finish] в конце обязателен, и это не формальность: без него полоса
/// замирает, не дойдя до конца, — последний кусок приходит раньше, чем
/// истечёт промежуток, — и выглядит это как оборванная загрузка.
class ProgressThrottle {
  ProgressThrottle(
    this.report, {
    this.interval = const Duration(milliseconds: 100),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _reported = _now();
  }

  /// Что сообщать: сколько принято и сколько всего — знает вызывающий, у
  /// него эти числа и лежат.
  final void Function() report;

  final Duration interval;
  final DateTime Function() _now;
  late DateTime _reported;

  /// Пришёл очередной кусок. Сообщит, если пора.
  void tick() {
    final now = _now();
    if (now.difference(_reported) < interval) return;
    _reported = now;
    report();
  }

  /// Работа кончилась — сообщаем непременно.
  void finish() {
    _reported = _now();
    report();
  }
}
