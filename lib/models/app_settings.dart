import 'package:equatable/equatable.dart';

import '../input/gamepad_binding.dart';
import 'appearance.dart';
import 'proxy_settings.dart';
import 'save_automation.dart';
import 'speed_limits.dart';
import 'startup_settings.dart';

export 'appearance.dart';
export 'save_automation.dart';
export 'startup_settings.dart';

/// Настройки приложения.
///
/// **Не девятнадцать полей, а девять, и три из них — значения.** То, что
/// правится из одной карточки и читается вместе, лежит одним значением:
/// [appearance] (схема, язык, масштабы, украшения), [startup] (автозапуск,
/// окно, проверка обновлений) и [saves] (папка синхронизации и
/// автоснимки). Правка одной части — `s.withAppearance((a) =>
/// a.copyWith(…))` — другую не задевает уже по устройству, а
/// тот, кто читает одну часть (`select` по `appearance`), не
/// перестраивается от правки другой.
///
/// **На диске запись осталась плоской**, с прежними ключами: каждая часть
/// читает свои из общей карты и туда же пишет. Файл настроек лежит у людей
/// на дисках, и разбор модели его касаться не должен.
class AppSettings extends Equatable {
  const AppSettings({
    required this.installDir,
    this.maxConcurrent = 3,
    this.systemNotifications = true,
    this.appearance = const Appearance(),
    this.startup = const StartupSettings(),
    this.saves = const SaveAutomation(),
    this.proxy = const ProxySettings(),
    this.limits = SpeedLimits.unlimited,
    this.gamepad = const GamepadBinding(),
  });

  /// Куда складывать игры.
  final String installDir;

  final int maxConcurrent;

  /// Системные уведомления о том, что закончилось в фоне: загрузка,
  /// неудавшийся автоснимок сохранений.
  final bool systemNotifications;

  /// Схема, язык, масштабы и украшения.
  final Appearance appearance;

  /// Автозапуск, окно при запуске и проверка обновлений.
  final StartupSettings startup;

  /// Папка синхронизации и автоснимки.
  final SaveAutomation saves;

  /// Ограничения скорости, в том числе на время игры.
  final SpeedLimits limits;

  /// HTTP-прокси для движка загрузок.
  final ProxySettings proxy;

  /// Раскладка геймпада и зона нечувствительности стиков.
  final GamepadBinding gamepad;

  /// Сколько загрузок может идти разом — ровно то, что предлагает список в
  /// настройках. Из файла число сводится к ближайшему варианту: ноль
  /// остановил бы очередь навсегда, а число мимо списка уронило бы сам
  /// список — `DropdownButton` не показывает значение, которого в нём нет.
  static const concurrencyOptions = [1, 2, 3, 5, 8];

  AppSettings copyWith({
    String? installDir,
    int? maxConcurrent,
    bool? systemNotifications,
    Appearance? appearance,
    StartupSettings? startup,
    SaveAutomation? saves,
    ProxySettings? proxy,
    SpeedLimits? limits,
    GamepadBinding? gamepad,
  }) => AppSettings(
    installDir: installDir ?? this.installDir,
    maxConcurrent: maxConcurrent ?? this.maxConcurrent,
    systemNotifications: systemNotifications ?? this.systemNotifications,
    appearance: appearance ?? this.appearance,
    startup: startup ?? this.startup,
    saves: saves ?? this.saves,
    proxy: proxy ?? this.proxy,
    limits: limits ?? this.limits,
    gamepad: gamepad ?? this.gamepad,
  );

  /// Правка облика — самая частая, и выписывать её вложенным `copyWith`
  /// по месту значило бы каждый раз повторять, откуда облик берётся.
  AppSettings withAppearance(Appearance Function(Appearance) edit) =>
      copyWith(appearance: edit(appearance));

  AppSettings withStartup(StartupSettings Function(StartupSettings) edit) =>
      copyWith(startup: edit(startup));

  AppSettings withSaves(SaveAutomation Function(SaveAutomation) edit) =>
      copyWith(saves: edit(saves));

  Map<String, dynamic> toJson() => {
    'installDir': installDir,
    'maxConcurrent': maxConcurrent,
    'systemNotifications': systemNotifications,
    ...appearance.toJson(),
    ...startup.toJson(),
    ...saves.toJson(),
    'proxy': proxy.toJson(),
    'limits': limits.toJson(),
    'gamepad': gamepad.toJson(),
  };

  factory AppSettings.fromJson(Map<String, dynamic> json, String fallbackDir) =>
      AppSettings(
        installDir: json['installDir'] as String? ?? fallbackDir,
        maxConcurrent: _concurrency(json['maxConcurrent']),
        systemNotifications: json['systemNotifications'] as bool? ?? true,
        appearance: Appearance.fromJson(json),
        startup: StartupSettings.fromJson(json),
        saves: SaveAutomation.fromJson(json),
        limits: json['limits'] == null
            ? SpeedLimits.unlimited
            : SpeedLimits.fromJson(json['limits'] as Map<String, dynamic>),
        proxy: json['proxy'] == null
            ? const ProxySettings()
            : ProxySettings.fromJson(json['proxy'] as Map<String, dynamic>),
        gamepad: json['gamepad'] == null
            ? const GamepadBinding()
            : GamepadBinding.fromJson(json['gamepad'] as Map<String, dynamic>),
      );

  @override
  List<Object?> get props => [
    installDir,
    maxConcurrent,
    systemNotifications,
    appearance,
    startup,
    saves,
    proxy,
    limits,
    gamepad,
  ];

  static int _concurrency(Object? value) {
    if (value is! int) return 3;
    var nearest = concurrencyOptions.first;
    for (final option in concurrencyOptions) {
      if ((option - value).abs() < (nearest - value).abs()) nearest = option;
    }
    return nearest;
  }
}
