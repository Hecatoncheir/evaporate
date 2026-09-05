import 'dart:async';

import 'package:evaporate/services/system/app_shutdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('шаги выполняются по порядку', () async {
    final done = <String>[];
    await AppShutdown([
      () async => done.add('окно'),
      () async => done.add('библиотека'),
      () async => done.add('движок'),
    ]).run();

    expect(done, ['окно', 'библиотека', 'движок']);
  });

  test('сорвавшийся шаг не отменяет остальные', () async {
    final done = <String>[];
    final errors = <Object>[];
    await AppShutdown([
      () async => throw StateError('движок не отвечает'),
      () async => done.add('библиотека'),
    ], onError: errors.add).run();

    expect(done, ['библиотека']);
    expect(errors.single, isA<StateError>());
  });

  test('зависший шаг не задерживает закрытие окна', () async {
    final done = <String>[];
    // Настоящий таймер, но короткий: проверяем, что предел вообще есть,
    // а его величина — дело настройки, а не поведения.
    await AppShutdown([
      () => Completer<void>().future,
      () async => done.add('библиотека'),
    ], stepTimeout: const Duration(milliseconds: 20)).run();

    expect(done, ['библиотека']);
  });

  // Одного предела на шаг мало: полдесятка зависших шагов складываются в
  // полминуты окна, которое не убрать.
  test('общий бюджет ограничивает завершение целиком', () async {
    final done = <String>[];
    final errors = <Object>[];
    final elapsed = Stopwatch()..start();

    await AppShutdown(
      [
        () => Completer<void>().future,
        () => Completer<void>().future,
        // Шаг не мгновенный намеренно. Два предыдущих съедают бюджет ровно
        // до нуля, и от того, осталось ли после них полмиллисекунды,
        // зависеть проверка не должна: на загруженной машине сборки это
        // выпадало то так, то этак.
        () async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          done.add('до этого шага не дошли');
        },
      ],
      stepTimeout: const Duration(milliseconds: 40),
      budget: const Duration(milliseconds: 60),
      onError: errors.add,
    ).run();

    expect(done, isEmpty);
    expect(elapsed.elapsed, lessThan(const Duration(seconds: 1)));
    expect(errors.last, isA<TimeoutException>());
  });

  test('повторный вызов ничего не переписывает', () async {
    var calls = 0;
    final shutdown = AppShutdown([() async => calls++]);

    await shutdown.run();
    await shutdown.run();

    expect(calls, 1);
    expect(shutdown.isStarted, isTrue);
  });
}
