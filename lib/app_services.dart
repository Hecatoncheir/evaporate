import 'dart:async';

import 'package:flutter/foundation.dart';

import 'bloc/downloads/downloads_bloc.dart';
import 'bloc/library/library_bloc.dart';
import 'bloc/saves/saves_bloc.dart';
import 'bloc/settings/settings_bloc.dart';
import 'core/app_paths.dart';
import 'input/gamepad_service.dart';
import 'l10n/app_localizations.dart';
import 'services/notifications/notification_service.dart';
import 'services/notifications/system_notification_service.dart';
import 'services/system/app_shutdown.dart';
import 'services/system/proxy_http_overrides.dart';

/// Блоки и службы приложения, собранные в нужном порядке.
///
/// Отдельно от `main`, потому что порядок здесь свой и объяснённый:
/// сохранения подписываются на библиотеку, загрузки правят её игры, а
/// гаснет всё в обратном порядке создания. В `main` же остаётся то, что
/// делается один раз и до всего: журнал, настройки, окно, трей.
class AppServices {
  AppServices._({
    required this.library,
    required this.saves,
    required this.downloads,
    required this.gamepad,
    required this.notifications,
  });

  final LibraryBloc library;
  final SavesBloc saves;
  final DownloadsBloc downloads;
  final GamepadService gamepad;
  final NotificationService notifications;

  /// Поднимает всё и дописывает в [shutdownSteps], что гасить при выходе.
  ///
  /// Порядок создания: библиотека, потом сохранения (они подписываются на
  /// её события и ставят ей хук «снять сейв перед запуском»), потом
  /// загрузки. Порядок гашения обратный, и он важен: движок гасим раньше
  /// сохранений и библиотеки, потому что его задачи ещё правят её игры;
  /// сохранения — раньше библиотеки, они на неё подписаны; настройки —
  /// последними, на них смотрят все.
  static Future<AppServices> bootstrap({
    required AppPaths paths,
    required SettingsBloc settings,
    required L Function() localizations,
    required List<ShutdownStep> shutdownSteps,
    ValueListenable<ProxyRouting>? proxyRouting,
  }) async {
    final notifications = await _notifications(localizations);

    final library = LibraryBloc(
      paths: paths,
      settings: settings,
      localizations: localizations,
    );
    library.add(const LibraryLoadRequested());

    final saves = SavesBloc(
      paths: paths,
      library: library,
      settings: settings,
      notifications: notifications,
      localizations: localizations,
    );
    saves.add(const SavesLoadRequested());

    final downloads = DownloadsBloc(
      paths: paths,
      library: library,
      settings: settings,
      notifications: notifications,
      localizations: localizations,
      proxyRouting: proxyRouting,
    );
    // Движок поднимается в фоне: даже если он не поднимется, приложение
    // должно открыться — библиотекой и сейвами можно пользоваться.
    downloads.add(const DownloadEngineStartRequested());

    final gamepad = _gamepad(settings);
    shutdownSteps.addAll([
      downloads.close,
      saves.close,
      library.close,
      settings.close,
      () async => gamepad.dispose(),
    ]);

    return AppServices._(
      library: library,
      saves: saves,
      downloads: downloads,
      gamepad: gamepad,
      notifications: notifications,
    );
  }

  /// Разрешение у системы не спрашиваем на старте: это делает человек
  /// кнопкой в настройках, чтобы диалог не выскакивал при первом запуске.
  static Future<NotificationService> _notifications(
    L Function() localizations,
  ) async {
    final notifications = SystemNotificationService(
      localizations: localizations,
    );
    await notifications.initialize();
    return notifications;
  }

  /// Отсутствие геймпада не должно мешать запуску — сервис это переживает
  /// сам, поэтому запуск идёт без ожидания.
  static GamepadService _gamepad(SettingsBloc settings) {
    final gamepad = GamepadService(binding: settings.state.gamepad);
    unawaited(gamepad.start());
    return gamepad;
  }
}
