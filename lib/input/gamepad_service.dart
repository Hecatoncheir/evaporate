import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gamepads/gamepads.dart';

import 'gamepad_binding.dart';
import 'nav_action.dart';
import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_ru.dart';

/// Превращает поток событий геймпада в поток [NavAction].
///
/// Здесь живут три вещи, без которых геймпад в интерфейсе неудобен:
/// зона нечувствительности с гистерезисом, автоповтор при удержании и
/// подавление дребезга кнопок.
class GamepadService {
  GamepadService({
    GamepadBinding binding = const GamepadBinding(),
    this.source,
    this.repeatDelay = const Duration(milliseconds: 400),
    this.repeatInterval = const Duration(milliseconds: 110),
    L Function()? localizations,
  }) : _localizations = localizations ?? _defaultLocalizations {
    _binding = binding;
  }

  /// Откуда брать переводы. Сообщения отсюда доходят до пользователя через
  /// уведомления, поэтому язык им нужен, а `BuildContext` взять неоткуда.
  final L Function() _localizations;

  L get _l => _localizations();

  static L _defaultLocalizations() => LRu();

  /// Поток событий; в тестах подменяется, в приложении берётся из плагина.
  final Stream<NormalizedGamepadEvent>? source;
  final Duration repeatDelay;
  final Duration repeatInterval;

  late GamepadBinding _binding;

  final _actions = StreamController<NavAction>.broadcast();
  final _rawButtons = StreamController<GamepadButton>.broadcast();
  final _status = ValueNotifier<GamepadStatus>(const GamepadStatus());

  StreamSubscription<NormalizedGamepadEvent>? _subscription;

  /// Действия, удерживаемые прямо сейчас, и их таймеры автоповтора.
  final Map<NavAction, Timer> _repeaters = {};
  final Set<NavAction> _held = {};
  final Set<GamepadButton> _pressed = {};

  Stream<NavAction> get actions => _actions.stream;

  /// Сырые нажатия — нужны экрану переназначения кнопок.
  Stream<GamepadButton> get buttonPresses => _rawButtons.stream;

  ValueListenable<GamepadStatus> get status => _status;

  GamepadBinding get binding => _binding;

  set binding(GamepadBinding value) {
    final wasEnabled = _binding.enabled;
    _binding = value;
    if (value.enabled && !wasEnabled) {
      start();
    } else if (!value.enabled && wasEnabled) {
      stop();
    }
  }

  Future<void> start() async {
    if (_subscription != null || !_binding.enabled) return;
    try {
      final stream = source ?? Gamepads.normalizedEvents;
      _subscription = stream.listen(
        handleEvent,
        onError: (Object error) {
          _status.value = GamepadStatus(
            available: false,
            message: _l.gamepadReadFailed('$error'),
          );
        },
      );
      _status.value = const GamepadStatus(available: true);
      await refreshDevices();
    } on Object catch (error) {
      // На машине может не быть поддержки — приложение продолжает работать
      // с мышью и клавиатурой.
      _status.value = GamepadStatus(
        available: false,
        message: _l.gamepadUnavailable('$error'),
      );
    }
  }

  /// Когда список устройств переспрашивали в последний раз.
  DateTime? _lastRecheck;

  /// Не чаще раза в секунду: события с геймпада идут десятками в секунду, и
  /// спрашивать плагин на каждое — заметно дороже, чем оно того стоит.
  /// Список может и остаться пустым — плагин не всегда видит устройство,
  /// события которого пропускает.
  void _recheckDevices() {
    final now = DateTime.now();
    final last = _lastRecheck;
    if (last != null && now.difference(last) < const Duration(seconds: 1)) {
      return;
    }
    _lastRecheck = now;
    unawaited(refreshDevices());
  }

  Future<void> refreshDevices() async {
    if (source != null) return;
    try {
      final list = await Gamepads.list();
      _status.value = GamepadStatus(
        available: true,
        devices: [for (final device in list) device.name],
      );
    } on Object catch (error) {
      _status.value = GamepadStatus(
        available: false,
        message: _l.gamepadListFailed('$error'),
      );
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _cancelAllRepeats();
    _held.clear();
    _pressed.clear();
  }

  /// Открыто для тестов: позволяет прогнать сценарий без железа.
  @visibleForTesting
  void handleEvent(NormalizedGamepadEvent event) {
    // Список устройств спрашивают один раз, при запуске, и геймпад,
    // подключённый позже, в него не попадал: сам он работал, но подсказки
    // управления внизу окна молчали, потому что смотрят на этот список.
    // Пришедшее событие — доказательство, что устройство есть.
    if (!_status.value.hasDevice) _recheckDevices();
    final button = event.button;
    if (button != null) {
      _handleButton(button, event.value);
      return;
    }
    final axis = event.axis;
    if (axis != null) _handleAxis(axis, event.value);
  }

  void _handleButton(GamepadButton button, double value) {
    final isDown = value >= 0.5;
    final wasDown = _pressed.contains(button);
    if (isDown == wasDown) return;

    if (isDown) {
      _pressed.add(button);
      _rawButtons.add(button);
      final action = _binding.actionFor(button);
      if (action != null) _begin(action);
    } else {
      _pressed.remove(button);
      final action = _binding.actionFor(button);
      if (action != null) _end(action);
    }
  }

  void _handleAxis(GamepadAxis axis, double value) {
    switch (axis) {
      case GamepadAxis.leftStickX:
        _applyAxis(value, negative: NavAction.left, positive: NavAction.right);
      case GamepadAxis.leftStickY:
        // По соглашению пакета вверх — это +1.
        _applyAxis(value, negative: NavAction.down, positive: NavAction.up);
      case GamepadAxis.rightStickY:
        _applyAxis(
          value,
          negative: NavAction.scrollDown,
          positive: NavAction.scrollUp,
        );
      case GamepadAxis.rightStickX:
      case GamepadAxis.leftTrigger:
      case GamepadAxis.rightTrigger:
        break;
    }
  }

  /// Одна ось даёт два взаимоисключающих направления, поэтому и включение,
  /// и выключение считаются здесь же.
  void _applyAxis(
    double value, {
    required NavAction negative,
    required NavAction positive,
  }) {
    final active = _held.contains(negative)
        ? negative
        : (_held.contains(positive) ? positive : null);

    final NavAction? wanted;
    if (value >= _binding.deadzone) {
      wanted = positive;
    } else if (value <= -_binding.deadzone) {
      wanted = negative;
    } else if (active != null && value.abs() <= _binding.releaseZone) {
      wanted = null;
    } else {
      // Между зонами отпускания и срабатывания ничего не меняем.
      return;
    }

    if (active == wanted) return;
    if (active != null) _end(active);
    if (wanted != null) _begin(wanted);
  }

  void _begin(NavAction action) {
    if (!_held.add(action)) return;
    _actions.add(action);
    if (!action.repeats) return;

    _repeaters[action]?.cancel();
    _repeaters[action] = Timer(repeatDelay, () {
      _repeaters[action] = Timer.periodic(repeatInterval, (_) {
        if (_held.contains(action)) {
          _actions.add(action);
        } else {
          _cancelRepeat(action);
        }
      });
    });
  }

  void _end(NavAction action) {
    _held.remove(action);
    _cancelRepeat(action);
  }

  void _cancelRepeat(NavAction action) {
    _repeaters.remove(action)?.cancel();
  }

  void _cancelAllRepeats() {
    for (final timer in _repeaters.values) {
      timer.cancel();
    }
    _repeaters.clear();
  }

  void dispose() {
    unawaited(stop());
    _actions.close();
    _rawButtons.close();
    _status.dispose();
  }
}

class GamepadStatus {
  const GamepadStatus({
    this.available = false,
    this.devices = const [],
    this.message,
  });

  final bool available;
  final List<String> devices;
  final String? message;

  bool get hasDevice => devices.isNotEmpty;

  /// Имя единственного устройства, если оно одно. Остальные состояния
  /// описываются словами и потому живут в слое интерфейса —
  /// `gamepadStatusLabel`: у класса-значения языка взять неоткуда.
  String? get soleDevice => devices.length == 1 ? devices.first : null;
}
