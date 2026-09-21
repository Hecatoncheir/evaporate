import 'dart:async';

import 'package:evaporate/services/system/app_shutdown.dart';
import 'package:evaporate/services/system/managed_window.dart';
import 'package:flutter/services.dart';
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

  group('конец процесса', () {
    const channel = MethodChannel('window_manager');

    List<String> watchWindow() {
      TestWidgetsFlutterBinding.ensureInitialized();
      final calls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      return calls;
    }

    // Штатное разрушение окна на Windows роняет процесс внутри
    // flutter_windows.dll: движок разбирают, пока в него ещё стучатся
    // опрос геймпада, уведомления и задачи движка загрузок. Человек видел
    // «программа перестала работать» после каждого закрытия.
    test('на Windows процесс заканчивается сам, без разрушения окна', () async {
      final calls = watchWindow();
      final done = <String>[];
      final codes = <int>[];

      await WindowCloseHandler(
        AppShutdown([() async => done.add('записи легли')]),
        exitProcess: codes.add,
        platform: 'windows',
      ).quit();

      expect(done, ['записи легли']);
      expect(codes, [0]);
      expect(calls, isNot(contains('destroy')));
    });

    // На остальных системах разбор проходит без приключений, и обрывать
    // его незачем: там окно закрывают, как и полагается.
    test('на macOS окно закрывается штатно', () async {
      final calls = watchWindow();
      final codes = <int>[];

      await WindowCloseHandler(
        AppShutdown(const []),
        exitProcess: codes.add,
        platform: 'macos',
      ).quit();

      expect(calls, contains('destroy'));
      expect(codes, isEmpty);
    });

    // Второе «Закрыть» во время завершения: `run()` возвращался сразу, и
    // второй `quit()` тут же заканчивал процесс — посреди первого прохода,
    // так и не дописав его шаги. А окно до восьми секунд оставалось на
    // экране и нажималось.
    test('второе закрытие ждёт первое, а окно прячется сразу', () async {
      final calls = watchWindow();
      final step = Completer<void>();
      final codes = <int>[];
      final handler = WindowCloseHandler(
        AppShutdown([() => step.future]),
        exitProcess: codes.add,
        platform: 'windows',
      );

      final first = handler.quit();
      final second = handler.quit();
      await pumpEventQueue();

      expect(codes, isEmpty, reason: 'процесс кончился посреди завершения');
      expect(calls, contains('hide'));
      step.complete();
      await Future.wait([first, second]);
      expect(codes, isNotEmpty);
    });
  });
}
