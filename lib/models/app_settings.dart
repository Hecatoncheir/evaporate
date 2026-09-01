import 'package:equatable/equatable.dart';

import '../input/gamepad_binding.dart';
import 'proxy_settings.dart';

class AppSettings extends Equatable {
  const AppSettings({
    required this.installDir,
    this.maxConcurrent = 3,
    this.syncFolder,
    this.autoExportToSync = true,
    this.autoSnapshotOnExit = true,
    this.systemNotifications = true,
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
    proxy,
    gamepad,
  ];

  static const _u = Object();
}
