import 'package:evaporate/core/progress_throttle.dart';
import 'package:flutter_test/flutter_test.dart';

/// Прореживание отчётов о ходе: кусков приходят тысячи, а перерисовывать
/// окно на каждый — значит тратить на показ больше, чем на саму загрузку.
void main() {
  late DateTime clock;
  late int reports;
  late ProgressThrottle throttle;

  setUp(() {
    clock = DateTime(2026);
    reports = 0;
    throttle = ProgressThrottle(
      () => reports++,
      interval: const Duration(milliseconds: 100),
      now: () => clock,
    );
  });

  void wait(int ms) => clock = clock.add(Duration(milliseconds: ms));

  test('частые куски не поднимают отчёт на каждый', () {
    for (var i = 0; i < 100; i++) {
      throttle.tick();
    }

    expect(reports, 0);
  });

  test('промежуток прошёл — отчёт идёт', () {
    wait(150);
    throttle.tick();

    expect(reports, 1);
  });

  test('после отчёта отсчёт начинается заново', () {
    wait(150);
    throttle
      ..tick()
      ..tick();
    wait(150);
    throttle.tick();

    expect(reports, 2);
  });

  // Без этого полоса замирает, не дойдя до конца: последний кусок приходит
  // раньше, чем истечёт промежуток, — и выглядит это как оборванная
  // загрузка.
  test('конец работы сообщается непременно', () {
    throttle
      ..tick()
      ..finish();

    expect(reports, 1);
  });
}
