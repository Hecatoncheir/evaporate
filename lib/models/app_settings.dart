import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../input/gamepad_binding.dart';
import 'proxy_settings.dart';
import 'window_start_mode.dart';

class AppSettings extends Equatable {
  const AppSettings({
    required this.installDir,
    this.maxConcurrent = 3,
    this.syncFolder,
    this.autoExportToSync = true,
    this.autoSnapshotOnExit = true,
    this.systemNotifications = true,
    this.launchAtStartup = false,
    this.windowStart = WindowStartMode.remembered,
    this.checkUpdates = true,
    this.themeMode = ThemeMode.system,
    this.ludusaviPath,
    this.proxy = const ProxySettings(),
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
  /// Приложение ничего не скачивает и не ставит само — только сообщает.
  final bool checkUpdates;

  /// Светлая, тёмная или как в системе.
  final ThemeMode themeMode;

  /// Путь к Ludusavi, если он установлен не там, где мы его ищем.
  /// Пустое значение означает «искать самим».
  final String? ludusaviPath;

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
    bool? systemNotifications,
    bool? launchAtStartup,
    WindowStartMode? windowStart,
    bool? checkUpdates,
    ThemeMode? themeMode,
    Object? ludusaviPath = _u,
    ProxySettings? proxy,
    GamepadBinding? gamepad,
  }) {
    return AppSettings(
      installDir: installDir ?? this.installDir,
      maxConcurrent: maxConcurrent ?? this.maxConcurrent,
      syncFolder: syncFolder == _u ? this.syncFolder : syncFolder as String?,
      autoExportToSync: autoExportToSync ?? this.autoExportToSync,
      autoSnapshotOnExit: autoSnapshotOnExit ?? this.autoSnapshotOnExit,
      systemNotifications: systemNotifications ?? this.systemNotifications,
      launchAtStartup: launchAtStartup ?? this.launchAtStartup,
      windowStart: windowStart ?? this.windowStart,
      checkUpdates: checkUpdates ?? this.checkUpdates,
      themeMode: themeMode ?? this.themeMode,
      ludusaviPath: ludusaviPath == _u
          ? this.ludusaviPath
          : ludusaviPath as String?,
      proxy: proxy ?? this.proxy,
      gamepad: gamepad ?? this.gamepad,
    );
  }

  Map<String, dynamic> toJson() => {
    'installDir': installDir,
    'maxConcurrent': maxConcurrent,
    if (syncFolder != null) 'syncFolder': syncFolder,
    'autoExportToSync': autoExportToSync,
    'autoSnapshotOnExit': autoSnapshotOnExit,
    'systemNotifications': systemNotifications,
    'launchAtStartup': launchAtStartup,
    'windowStart': windowStart.name,
    'checkUpdates': checkUpdates,
    'themeMode': themeMode.name,
    if (ludusaviPath != null) 'ludusaviPath': ludusaviPath,
    'proxy': proxy.toJson(),
    'gamepad': gamepad.toJson(),
  };

  factory AppSettings.fromJson(Map<String, dynamic> json, String fallbackDir) =>
      AppSettings(
        installDir: json['installDir'] as String? ?? fallbackDir,
        maxConcurrent: json['maxConcurrent'] as int? ?? 3,
        syncFolder: json['syncFolder'] as String?,
        autoExportToSync: json['autoExportToSync'] as bool? ?? true,
        autoSnapshotOnExit: json['autoSnapshotOnExit'] as bool? ?? true,
        systemNotifications: json['systemNotifications'] as bool? ?? true,
        launchAtStartup: json['launchAtStartup'] as bool? ?? false,
        windowStart: _windowStartFromJson(json),
        checkUpdates: json['checkUpdates'] as bool? ?? true,
        themeMode: _themeModeFromName(json['themeMode'] as String?),
        ludusaviPath: json['ludusaviPath'] as String?,
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
    systemNotifications,
    launchAtStartup,
    windowStart,
    checkUpdates,
    themeMode,
    ludusaviPath,
    proxy,
    gamepad,
  ];

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
  static ThemeMode _themeModeFromName(String? name) => switch (name) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static const _u = Object();
}
