import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'bloc/downloads/downloads_bloc.dart';
import 'bloc/library/library_bloc.dart';
import 'bloc/navigation/navigation_bloc.dart';
import 'bloc/settings/settings_bloc.dart';
import 'core/app_paths.dart';
import 'core/json_store.dart';
import 'input/gamepad_service.dart';
import 'models/app_settings.dart';
import 'services/notifications/notification_service.dart';
import 'services/notifications/system_notification_service.dart';
import 'services/system/managed_window.dart';
import 'services/system/update_check.dart';
import 'services/system/window_state.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final paths = await AppPaths.init();

  final settings = SettingsBloc(paths);
  settings.add(const SettingsLoadRequested());
  // Настройки нужны блокам загрузок и библиотеки уже в конструкторе,
  // поэтому дожидаемся первого состояния из хранилища.
  await settings.stream.first.timeout(
    const Duration(seconds: 2),
    onTimeout: () => settings.state,
  );

  // Окно ставим до того, как оно появится на экране: иначе пользователь
  // увидит, как оно прыгает из одного положения в другое.
  await windowManager.ensureInitialized();
  final window = WindowState(
    store: JsonStore(paths.windowStateFile),
    controller: const ManagedWindowController(),
  );
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      title: 'Evaporate',
      minimumSize: Size(WindowGeometry.minWidth, WindowGeometry.minHeight),
    ),
    () => window.restore(
      remember: settings.state.rememberWindowSize,
      alwaysMaximized: settings.state.startMaximized,
    ),
  );
  // Пишем всегда, даже когда восстановление выключено: включив его позже,
  // пользователь получит осмысленные значения, а не размер по умолчанию.
  WindowStateSaver(window).attach();

  // Разрешение у системы не спрашиваем на старте: это делает пользователь
  // кнопкой в настройках, чтобы диалог не выскакивал при первом запуске.
  final notifications = SystemNotificationService();
  await notifications.initialize();

  final library = LibraryBloc(
    paths: paths,
    settings: settings,
    notifications: notifications,
  );
  library.add(const LibraryLoadRequested());

  final downloads = DownloadsBloc(
    paths: paths,
    library: library,
    settings: settings,
    notifications: notifications,
  );
  // Движок поднимается в фоне: без aria2c приложение всё равно должно
  // открыться — библиотекой и сейвами можно пользоваться.
  downloads.add(const DownloadEngineStartRequested());

  final gamepad = GamepadService(binding: settings.state.gamepad);
  // Отсутствие геймпада не должно мешать запуску — сервис это переживает сам.
  unawaited(gamepad.start());

  // В фоне и без ожидания: сеть может не ответить, а приложение должно
  // открыться сразу. Молчим и при ошибке — недоступный GitHub не повод
  // встречать пользователя сообщением.
  if (settings.state.checkUpdates) {
    unawaited(_announceUpdate(notifications, settings));
  }

  runApp(
    EvaporateApp(
      settings: settings,
      library: library,
      downloads: downloads,
      gamepad: gamepad,
      notifications: notifications,
    ),
  );
}

class EvaporateApp extends StatelessWidget {
  const EvaporateApp({
    super.key,
    required this.settings,
    required this.library,
    required this.downloads,
    required this.gamepad,
    required this.notifications,
  });

  final SettingsBloc settings;
  final LibraryBloc library;
  final DownloadsBloc downloads;
  final GamepadService gamepad;
  final NotificationService notifications;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: settings),
        BlocProvider.value(value: library),
        BlocProvider.value(value: downloads),
        BlocProvider(create: (_) => NavigationBloc()),
      ],
      // Сервис ввода состояния не имеет — его внедряет обычный Provider,
      // на котором flutter_bloc и так построен.
      child: MultiProvider(
        providers: [
          Provider.value(value: gamepad),
          Provider<NotificationService>.value(value: notifications),
        ],
        child: BlocSelector<SettingsBloc, AppSettings, ThemeMode>(
          selector: (settings) => settings.themeMode,
          builder: (context, mode) => MaterialApp(
            title: 'Evaporate',
            debugShowCheckedModeBanner: false,
            theme: EvaporateTheme.light(),
            darkTheme: EvaporateTheme.dark(),
            themeMode: mode,
            home: const AppShell(),
          ),
        ),
      ),
    );
  }
}

/// Сообщает о вышедшей версии, если она есть.
Future<void> _announceUpdate(
  NotificationService notifications,
  SettingsBloc settings,
) async {
  try {
    final release = await UpdateCheck().latest();
    if (release == null) return;
    if (!settings.state.systemNotifications) return;
    await notifications.show(
      AppNotification(
        title: 'Вышла версия ${release.version}',
        body: 'Скачать можно на странице релизов на GitHub.',
        kind: NotificationKind.test,
      ),
    );
  } on Object {
    // Проверка обновлений — удобство, а не обязанность: недоступная сеть
    // не должна ничем оборачиваться для пользователя.
  }
}
