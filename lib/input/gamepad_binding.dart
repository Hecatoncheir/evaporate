import 'package:gamepads/gamepads.dart';

import 'nav_action.dart';

/// Раскладка геймпада: какая кнопка какому действию соответствует.
///
/// Пакет `gamepads` уже приводит железо к стандартной раскладке Xbox через
/// SDL-базу, поэтому здесь мы работаем с [GamepadButton], а не с сырыми
/// кодами. Раскладка всё равно вынесена в настройки: расположение A/B на
/// Nintendo-совместимых контроллерах зеркальное, и это вопрос вкуса.
class GamepadBinding {
  const GamepadBinding({
    this.buttons = defaultButtons,
    this.deadzone = 0.5,
    this.releaseZone = 0.35,
    this.enabled = true,
  });

  final Map<GamepadButton, NavAction> buttons;

  /// Отклонение стика, при котором направление считается нажатым.
  final double deadzone;

  /// Порог отпускания — ниже него направление сбрасывается. Гистерезис
  /// не даёт стику «дребезжать» на границе.
  final double releaseZone;

  final bool enabled;

  static const Map<GamepadButton, NavAction> defaultButtons = {
    GamepadButton.dpadUp: NavAction.up,
    GamepadButton.dpadDown: NavAction.down,
    GamepadButton.dpadLeft: NavAction.left,
    GamepadButton.dpadRight: NavAction.right,
    GamepadButton.a: NavAction.confirm,
    GamepadButton.b: NavAction.back,
    GamepadButton.x: NavAction.primaryAction,
    GamepadButton.y: NavAction.search,
    GamepadButton.rightBumper: NavAction.nextSection,
    GamepadButton.leftBumper: NavAction.prevSection,
  };

  NavAction? actionFor(GamepadButton button) => buttons[button];

  /// Кнопки, назначенные на действие (для подсказок и экрана настройки).
  List<GamepadButton> buttonsFor(NavAction action) => buttons.entries
      .where((e) => e.value == action)
      .map((e) => e.key)
      .toList();

  GamepadBinding copyWith({
    Map<GamepadButton, NavAction>? buttons,
    double? deadzone,
    double? releaseZone,
    bool? enabled,
  }) {
    return GamepadBinding(
      buttons: buttons ?? this.buttons,
      deadzone: deadzone ?? this.deadzone,
      releaseZone: releaseZone ?? this.releaseZone,
      enabled: enabled ?? this.enabled,
    );
  }

  /// Назначает кнопку на действие, снимая её с прежнего.
  GamepadBinding assign(GamepadButton button, NavAction action) {
    final next = Map<GamepadButton, NavAction>.from(buttons)..[button] = action;
    return copyWith(buttons: next);
  }

  GamepadBinding unassign(GamepadButton button) {
    final next = Map<GamepadButton, NavAction>.from(buttons)..remove(button);
    return copyWith(buttons: next);
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'deadzone': deadzone,
    'releaseZone': releaseZone,
    'buttons': {
      for (final entry in buttons.entries) entry.key.name: entry.value.name,
    },
  };

  factory GamepadBinding.fromJson(Map<String, dynamic> json) {
    final raw = json['buttons'] as Map<String, dynamic>?;
    final buttons = <GamepadButton, NavAction>{};
    if (raw != null) {
      raw.forEach((key, value) {
        final button = GamepadButton.values
            .where((b) => b.name == key)
            .firstOrNull;
        final action = NavAction.values
            .where((a) => a.name == value)
            .firstOrNull;
        if (button != null && action != null) buttons[button] = action;
      });
    }
    return GamepadBinding(
      buttons: buttons.isEmpty ? defaultButtons : buttons,
      deadzone: (json['deadzone'] as num?)?.toDouble() ?? 0.5,
      releaseZone: (json['releaseZone'] as num?)?.toDouble() ?? 0.35,
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

/// Человеческие названия кнопок — в подсказках и на экране настройки.
extension GamepadButtonLabel on GamepadButton {
  String get label => switch (this) {
    GamepadButton.a => 'A',
    GamepadButton.b => 'B',
    GamepadButton.x => 'X',
    GamepadButton.y => 'Y',
    GamepadButton.leftBumper => 'LB',
    GamepadButton.rightBumper => 'RB',
    GamepadButton.leftTrigger => 'LT',
    GamepadButton.rightTrigger => 'RT',
    GamepadButton.back => 'Back',
    GamepadButton.start => 'Start',
    GamepadButton.home => 'Guide',
    GamepadButton.leftStick => 'L3',
    GamepadButton.rightStick => 'R3',
    GamepadButton.dpadUp => 'D-pad ↑',
    GamepadButton.dpadDown => 'D-pad ↓',
    GamepadButton.dpadLeft => 'D-pad ←',
    GamepadButton.dpadRight => 'D-pad →',
    // Остальные кнопки называются буквами и в переводе не нуждаются;
    // эта — единственная словесная, её показывают через
    // `gamepadButtonLabel` в слое интерфейса.
    GamepadButton.touchpad => 'Touchpad',
  };
}
