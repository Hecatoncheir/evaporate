import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_service.dart';
import '../../l10n/app_localizations_ru.dart';

/// Реализация поверх `flutter_local_notifications` для macOS, Windows и Linux.
class SystemNotificationService implements NotificationService {
  SystemNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  bool _available = false;
  int _nextId = 0;

  /// Идентификатор приложения для Windows. Значение обязано быть постоянным:
  /// по нему система узнаёт отправителя уведомлений.
  static const _windowsGuid = 'a4f1c6d2-8b37-4e59-9c04-1d7ea25b6f83';

  @override
  bool get isAvailable => _available;

  @override
  Future<bool> initialize() async {
    if (!_isSupportedPlatform) return false;
    try {
      final settings = InitializationSettings(
        macOS: const DarwinInitializationSettings(
          // Разрешение спрашиваем отдельно и осознанно, а не при старте.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        linux: LinuxInitializationSettings(
          defaultActionName: LRu().notificationOpen,
        ),
        windows: const WindowsInitializationSettings(
          appName: 'Evaporate',
          appUserModelId: 'Evaporate.GameLauncher',
          guid: _windowsGuid,
        ),
      );
      _available = await _plugin.initialize(settings: settings) ?? false;
      return _available;
    } on Object {
      // Отсутствие службы уведомлений не должно мешать приложению работать.
      _available = false;
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!_available) return false;
    try {
      if (Platform.isMacOS) {
        final macOS = _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >();
        final granted = await macOS?.requestPermissions(
          alert: true,
          badge: false,
          sound: false,
        );
        return granted ?? false;
      }
      // Windows и Linux разрешения не спрашивают.
      return true;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> show(AppNotification notification) async {
    if (!_available) return;
    try {
      await _plugin.show(
        id: _nextId++,
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
          macOS: DarwinNotificationDetails(),
          linux: LinuxNotificationDetails(),
          windows: WindowsNotificationDetails(),
        ),
      );
    } on Object {
      // Уведомление — не критичный путь: молчим, но не роняем операцию.
    }
  }

  static bool get _isSupportedPlatform =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;
}
