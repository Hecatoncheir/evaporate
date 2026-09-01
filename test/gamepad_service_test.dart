import 'dart:async';

import 'package:evaporate/input/gamepad_binding.dart';
import 'package:evaporate/input/gamepad_service.dart';
import 'package:evaporate/input/nav_action.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamepads/gamepads.dart';

import 'support/test_app.dart';

void main() {
  late GamepadService service;
  late List<NavAction> received;
  late StreamSubscription<NavAction> subscription;

  void createService({
    GamepadBinding binding = const GamepadBinding(),
    Duration repeatDelay = const Duration(milliseconds: 40),
    Duration repeatInterval = const Duration(milliseconds: 20),
  }) {
    service = GamepadService(
      binding: binding,
      repeatDelay: repeatDelay,
      repeatInterval: repeatInterval,
    );
    received = [];
    subscription = service.actions.listen(received.add);
  }

  setUp(() => createService());

  tearDown(() async {
    await subscription.cancel();
    service.dispose();
  });

  /// Действия приходят через broadcast-поток, поэтому между отправкой
  /// события и проверкой нужно дать циклу событий провернуться.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  /// Ждёт выполнения условия, опрашивая его, — устойчиво к тому, насколько
  /// быстро VM успевает отработать реальные таймеры.
  Future<void> waitUntil(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('условие не выполнилось за $timeout');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  group('кнопки', () {
    test('нажатие даёт действие, отпускание — нет', () async {
      service.handleEvent(buttonEvent(GamepadButton.a, 1));
      await settle();
      expect(received, [NavAction.confirm]);

      service.handleEvent(buttonEvent(GamepadButton.a, 0));
      await settle();
      expect(received, [NavAction.confirm]);
    });

    test('повторное событие нажатия не удваивает действие', () async {
      service.handleEvent(buttonEvent(GamepadButton.b, 1));
      service.handleEvent(buttonEvent(GamepadButton.b, 1));
      service.handleEvent(buttonEvent(GamepadButton.b, 1));
      await settle();

      expect(received, [NavAction.back]);
    });

    test(
      'незанятая кнопка ничего не эмитит, но видна экрану настройки',
      () async {
        final pressed = <GamepadButton>[];
        final raw = service.buttonPresses.listen(pressed.add);

        service.handleEvent(buttonEvent(GamepadButton.touchpad, 1));
        await settle();

        expect(received, isEmpty);
        expect(pressed, [GamepadButton.touchpad]);
        await raw.cancel();
      },
    );

    test('переназначенная кнопка выполняет новое действие', () async {
      await subscription.cancel();
      service.dispose();
      createService(
        binding: const GamepadBinding().assign(
          GamepadButton.y,
          NavAction.primaryAction,
        ),
      );

      service.handleEvent(buttonEvent(GamepadButton.y, 1));
      await settle();

      expect(received, [NavAction.primaryAction]);
    });
  });

  group('стики', () {
    test('отклонение внутри мёртвой зоны игнорируется', () async {
      service.handleEvent(axisEvent(GamepadAxis.leftStickX, 0.3));
      await settle();

      expect(received, isEmpty);
    });

    test('отклонение за порог даёт направление один раз', () async {
      service.handleEvent(axisEvent(GamepadAxis.leftStickX, 0.8));
      service.handleEvent(axisEvent(GamepadAxis.leftStickX, 0.9));
      await settle();

      expect(received, [NavAction.right]);
    });

    test('вверх по оси Y — это положительное значение', () async {
      service.handleEvent(axisEvent(GamepadAxis.leftStickY, 0.9));
      await settle();
      expect(received, [NavAction.up]);

      service.handleEvent(axisEvent(GamepadAxis.leftStickY, -0.9));
      await settle();
      expect(received, [NavAction.up, NavAction.down]);
    });

    test(
      'гистерезис: возврат в промежуточную зону не сбрасывает удержание',
      () async {
        service.handleEvent(axisEvent(GamepadAxis.leftStickX, 0.8));
        await settle();
        // Между releaseZone (0.35) и deadzone (0.5) состояние не меняется.
        service.handleEvent(axisEvent(GamepadAxis.leftStickX, 0.45));
        service.handleEvent(axisEvent(GamepadAxis.leftStickX, 0.8));
        await settle();

        expect(received, [
          NavAction.right,
        ], reason: 'дребезг на границе не должен давать лишних шагов');
      },
    );

    test(
      'возврат в центр снимает удержание и позволяет шагнуть снова',
      () async {
        service.handleEvent(axisEvent(GamepadAxis.leftStickX, 0.8));
        service.handleEvent(axisEvent(GamepadAxis.leftStickX, 0.0));
        service.handleEvent(axisEvent(GamepadAxis.leftStickX, 0.8));
        await settle();

        expect(received, [NavAction.right, NavAction.right]);
      },
    );

    test('смена направления без прохода через центр', () async {
      service.handleEvent(axisEvent(GamepadAxis.leftStickX, 0.9));
      service.handleEvent(axisEvent(GamepadAxis.leftStickX, -0.9));
      await settle();

      expect(received, [NavAction.right, NavAction.left]);
    });

    test('правый стик прокручивает', () async {
      service.handleEvent(axisEvent(GamepadAxis.rightStickY, -0.9));
      await settle();

      expect(received, [NavAction.scrollDown]);
    });
  });

  group('автоповтор', () {
    test('удержание направления повторяет шаги', () async {
      service.handleEvent(buttonEvent(GamepadButton.dpadDown, 1));

      // Ждём условие, а не фиксированную паузу: таймеры здесь настоящие,
      // и под нагрузкой VM жёсткая задержка делает тест флакающим.
      await waitUntil(() => received.length >= 3);
      expect(received.every((a) => a == NavAction.down), isTrue);

      service.handleEvent(buttonEvent(GamepadButton.dpadDown, 0));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final afterRelease = received.length;
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(
        received.length,
        afterRelease,
        reason: 'после отпускания повторы прекращаются',
      );
    });

    test('подтверждение не повторяется при удержании', () async {
      service.handleEvent(buttonEvent(GamepadButton.a, 1));
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(received, [NavAction.confirm]);
    });
  });

  group('включение и выключение', () {
    test('выключённый геймпад не подписывается на события', () async {
      final events = StreamController<NormalizedGamepadEvent>.broadcast();
      final disabled = GamepadService(
        binding: const GamepadBinding(enabled: false),
        source: events.stream,
      );
      final got = <NavAction>[];
      final sub = disabled.actions.listen(got.add);

      await disabled.start();
      events.add(buttonEvent(GamepadButton.a, 1));
      await settle();

      expect(got, isEmpty);

      // Включение из настроек должно подхватываться на лету.
      disabled.binding = const GamepadBinding();
      await settle();
      events.add(buttonEvent(GamepadButton.a, 1));
      await settle();

      expect(got, [NavAction.confirm]);

      await sub.cancel();
      disabled.dispose();
      await events.close();
    });
  });

  test('раскладка переживает сохранение и чтение', () {
    const binding = GamepadBinding(deadzone: 0.62);
    final restored = GamepadBinding.fromJson(
      binding.assign(GamepadButton.start, NavAction.search).toJson(),
    );

    expect(restored.deadzone, closeTo(0.62, 1e-9));
    expect(restored.actionFor(GamepadButton.start), NavAction.search);
    expect(restored.actionFor(GamepadButton.a), NavAction.confirm);
  });
}
