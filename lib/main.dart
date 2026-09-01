import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'bloc/downloads/downloads_bloc.dart';
import 'bloc/library/library_bloc.dart';
import 'bloc/navigation/navigation_bloc.dart';
import 'bloc/settings/settings_bloc.dart';
import 'core/app_paths.dart';
import 'input/gamepad_service.dart';
import 'services/notifications/notification_service.dart';
import 'services/notifications/system_notification_service.dart';
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
        child: MaterialApp(
          title: 'Evaporate',
          debugShowCheckedModeBanner: false,
          theme: EvaporateTheme.build(),
          home: const AppShell(),
        ),
      ),
    );
  }
}
