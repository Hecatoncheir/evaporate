import 'package:equatable/equatable.dart';

import '../input/gamepad_binding.dart';
import 'app_theme_mode.dart';
import 'library_effect.dart';
import 'proxy_settings.dart';
import 'speed_limits.dart';
import 'window_start_mode.dart';

class AppSettings extends Equatable {
  const AppSettings({
    required this.installDir,
    this.maxConcurrent = 3,
    this.syncFolder,
    this.autoExportToSync = true,
    this.autoSnapshotOnExit = true,
    this.autoSnapshotOnLaunch = false,
    this.systemNotifications = true,
    this.launchAtStartup = false,
    this.windowStart = WindowStartMode.remembered,
    this.checkUpdates = true,
    this.themeMode = AppThemeMode.system,
    this.libraryEffects = true,
    this.effects = LibraryEffect.shipped,
    this.interfaceScale = 1,
    this.libraryScale = 1,
    this.locale,
    this.proxy = const ProxySettings(),
    this.limits = SpeedLimits.unlimited,
    this.gamepad = const GamepadBinding(),
  });

  /// Куда складывать игры.
  final String installDir;

  final int maxConcurrent;

  /// Папка облачной синхронизации (Dropbox/Syncthing/iCloud), через которую
  /// сейвы переезжают между устройствами.
  final String? syncFolder;
  final bool autoExportToSync;

  /// Глобальный дефолт: снимать сейв после выхода из игры.
  final bool autoSnapshotOnExit;

  /// Глобальный дефолт: снимать сейв ещё и перед запуском игры.
  final bool autoSnapshotOnLaunch;

  /// Системные уведомления о том, что закончилось в фоне: загрузка,
  /// неудавшийся автоснимок сохранений.
  final bool systemNotifications;

  /// Запускать приложение вместе с системой.
  ///
  /// Значение зеркалит состояние самой системы: её и спрашиваем при
  /// загрузке настроек, потому что автозапуск могли отключить снаружи.
  final bool launchAtStartup;

  /// Каким открывать окно при запуске.
  final WindowStartMode windowStart;

  /// Спрашивать при запуске, не вышла ли версия новее.
  ///
  /// Сама проверка ничего не скачивает: установку запускает пользователь.
  final bool checkUpdates;

  /// Светлая, тёмная или как в системе.
  final AppThemeMode themeMode;

  /// Общий выключатель; индивидуальные предпочтения сохраняются под ним.
  final bool libraryEffects;

  /// Какие украшения включены.
  ///
  /// Набором, а не полем на каждое: чем они отличаются друг от друга,
  /// сказано один раз — в [LibraryEffect], — а здесь остаётся только
  /// выбор человека.
  final Set<LibraryEffect> effects;

  /// Включено ли украшение само по себе.
  ///
  /// Общий выключатель здесь не участвует: смотреть на него — дело
  /// виджета, а рамка выбора ему и вовсе не подчиняется.
  bool isOn(LibraryEffect effect) => effects.contains(effect);

  /// Те же настройки с переключённым украшением.
  AppSettings withEffect(LibraryEffect effect, {required bool on}) => copyWith(
    effects: {
      for (final each in LibraryEffect.values)
        if (each == effect ? on : isOn(each)) each,
    },
  );

  /// Масштаб интерфейса и размер обложек независимы друг от друга и
  /// переживают перезапуск.
  final double interfaceScale;
  final double libraryScale;
  static const minInterfaceScale = 0.85;
  static const maxInterfaceScale = 1.25;
  static const minLibraryScale = 0.75;
  static const maxLibraryScale = 1.5;

  /// Сколько загрузок может идти разом — ровно то, что предлагает список в
  /// настройках. Из файла число сводится к ближайшему варианту: ноль
  /// остановил бы очередь навсегда, а число мимо списка уронило бы сам
  /// список — `DropdownButton` не показывает значение, которого в нём нет.
  static const concurrencyOptions = [1, 2, 3, 5, 8];

  /// Код языка интерфейса или null — брать язык системы.
  ///
  /// Хранится строкой, а не Locale: в файле настроек это всё равно
  /// строка, и лишний тип только добавил бы преобразований.
  final String? locale;

  /// Ограничения скорости, в том числе на время игры.
  final SpeedLimits limits;

  /// HTTP-прокси для движка загрузок.
  final ProxySettings proxy;

  /// Раскладка геймпада и зона нечувствительности стиков.
  final GamepadBinding gamepad;

  AppSettings copyWith({
    String? installDir,
    int? maxConcurrent,
    Object? syncFolder = _u,
    bool? autoExportToSync,
    bool? autoSnapshotOnExit,
    bool? autoSnapshotOnLaunch,
    bool? systemNotifications,
    bool? launchAtStartup,
    WindowStartMode? windowStart,
    bool? checkUpdates,
    AppThemeMode? themeMode,
    bool? libraryEffects,
    Set<LibraryEffect>? effects,
    double? interfaceScale,
    double? libraryScale,
    Object? locale = _u,
    ProxySettings? proxy,
    SpeedLimits? limits,
    GamepadBinding? gamepad,
  }) {
    return AppSettings(
      installDir: installDir ?? this.installDir,
      maxConcurrent: maxConcurrent ?? this.maxConcurrent,
      syncFolder: syncFolder == _u ? this.syncFolder : syncFolder as String?,
      autoExportToSync: autoExportToSync ?? this.autoExportToSync,
      autoSnapshotOnExit: autoSnapshotOnExit ?? this.autoSnapshotOnExit,
      autoSnapshotOnLaunch: autoSnapshotOnLaunch ?? this.autoSnapshotOnLaunch,
      systemNotifications: systemNotifications ?? this.systemNotifications,
      launchAtStartup: launchAtStartup ?? this.launchAtStartup,
      windowStart: windowStart ?? this.windowStart,
      checkUpdates: checkUpdates ?? this.checkUpdates,
      themeMode: themeMode ?? this.themeMode,
      libraryEffects: libraryEffects ?? this.libraryEffects,
      effects: effects ?? this.effects,
      interfaceScale: interfaceScale ?? this.interfaceScale,
      libraryScale: libraryScale ?? this.libraryScale,
      locale: locale == _u ? this.locale : locale as String?,
      proxy: proxy ?? this.proxy,
      limits: limits ?? this.limits,
      gamepad: gamepad ?? this.gamepad,
    );
  }

  Map<String, dynamic> toJson() => {
    'installDir': installDir,
    'maxConcurrent': maxConcurrent,
    if (syncFolder != null) 'syncFolder': syncFolder,
    'autoExportToSync': autoExportToSync,
    'autoSnapshotOnExit': autoSnapshotOnExit,
    'autoSnapshotOnLaunch': autoSnapshotOnLaunch,
    'systemNotifications': systemNotifications,
    'launchAtStartup': launchAtStartup,
    'windowStart': windowStart.name,
    'checkUpdates': checkUpdates,
    'themeMode': themeMode.name,
    'libraryEffects': libraryEffects,
    // Ключи прежние, по одному на украшение: профили, записанные до
    // появления набора, читаются как раньше — и записываются так же.
    for (final effect in LibraryEffect.values)
      effect.jsonKey: effects.contains(effect),
    'interfaceScale': interfaceScale,
    'libraryScale': libraryScale,
    if (locale != null) 'locale': locale,
    'proxy': proxy.toJson(),
    'limits': limits.toJson(),
    'gamepad': gamepad.toJson(),
  };

  factory AppSettings.fromJson(Map<String, dynamic> json, String fallbackDir) =>
      AppSettings(
        installDir: json['installDir'] as String? ?? fallbackDir,
        maxConcurrent: _concurrency(json['maxConcurrent']),
        syncFolder: json['syncFolder'] as String?,
        autoExportToSync: json['autoExportToSync'] as bool? ?? true,
        autoSnapshotOnExit: json['autoSnapshotOnExit'] as bool? ?? true,
        autoSnapshotOnLaunch: json['autoSnapshotOnLaunch'] as bool? ?? false,
        systemNotifications: json['systemNotifications'] as bool? ?? true,
        launchAtStartup: json['launchAtStartup'] as bool? ?? false,
        windowStart: _windowStartFromJson(json),
        checkUpdates: json['checkUpdates'] as bool? ?? true,
        themeMode: _themeModeFromName(json['themeMode'] as String?),
        libraryEffects: json['libraryEffects'] as bool? ?? true,
        effects: _effectsFromJson(json),
        interfaceScale: _scale(
          json['interfaceScale'],
          minInterfaceScale,
          maxInterfaceScale,
        ),
        libraryScale: _scale(
          json['libraryScale'],
          minLibraryScale,
          maxLibraryScale,
        ),
        locale: _localeFromJson(json['locale']),
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
    syncFolder,
    autoExportToSync,
    autoSnapshotOnExit,
    autoSnapshotOnLaunch,
    systemNotifications,
    launchAtStartup,
    windowStart,
    checkUpdates,
    themeMode,
    libraryEffects,
    effects,
    interfaceScale,
    libraryScale,
    locale,
    proxy,
    limits,
    gamepad,
  ];

  /// Незнакомый язык читается как «из системы»: приложение переведено
  /// не на все языки мира, и чужой файл настроек не должен оставлять
  /// пользователя перед пустым интерфейсом.
  static String? _localeFromJson(Object? value) {
    if (value is! String) return null;
    return supportedLocales.contains(value) ? value : null;
  }

  /// Языки, на которые приложение переведено.
  static const supportedLocales = ['ru', 'en'];

  /// Читает режим запуска, понимая и прежние две галочки: файл настроек
  /// у пользователя уже есть, и терять его выбор при обновлении нельзя.
  static WindowStartMode _windowStartFromJson(Map<String, dynamic> json) {
    final name = json['windowStart'] as String?;
    if (name != null) return WindowStartMode.fromName(name);
    if (json['startMaximized'] == true) return WindowStartMode.maximized;
    if (json['rememberWindowSize'] == false) {
      return WindowStartMode.maximized;
    }
    return WindowStartMode.remembered;
  }

  /// Неизвестное значение — это «как в системе»: чужой или испорченный
  /// файл настроек не должен запирать пользователя в чужой теме.
  /// Украшения из файла настроек.
  ///
  /// Ключи читаются по одному, как и писались: профиль, записанный до
  /// появления набора, приходит с прежними полями, а неназванное берёт
  /// значение по умолчанию — там могло не быть ещё и самого украшения.
  static Set<LibraryEffect> _effectsFromJson(Map<String, dynamic> json) => {
    for (final effect in LibraryEffect.values)
      if (json[effect.jsonKey] as bool? ??
          LibraryEffect.shipped.contains(effect))
        effect,
  };

  static AppThemeMode _themeModeFromName(String? name) => switch (name) {
    'light' => AppThemeMode.light,
    'dark' => AppThemeMode.dark,
    _ => AppThemeMode.system,
  };

  static const _u = Object();

  static int _concurrency(Object? value) {
    if (value is! int) return 3;
    var nearest = concurrencyOptions.first;
    for (final option in concurrencyOptions) {
      if ((option - value).abs() < (nearest - value).abs()) nearest = option;
    }
    return nearest;
  }

  static double _scale(Object? value, double min, double max) =>
      value is num && value.isFinite ? value.toDouble().clamp(min, max) : 1;
}
