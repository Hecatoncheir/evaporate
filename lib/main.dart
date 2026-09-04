import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'bloc/downloads/downloads_bloc.dart';
import 'bloc/library/library_bloc.dart';
import 'bloc/navigation/navigation_bloc.dart';
import 'bloc/settings/settings_bloc.dart';
import 'core/app_paths.dart';
import 'l10n/app_localizations.dart';
import 'core/json_store.dart';
import 'input/gamepad_service.dart';
import 'models/app_settings.dart';
import 'services/notifications/notification_service.dart';
import 'services/notifications/system_notification_service.dart';
import 'services/system/app_tray.dart';
import 'services/system/managed_window.dart';
import 'services/system/update_check.dart';
import 'services/system/window_state.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';
import 'ui/widgets/window_frame.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final paths = await AppPaths.init();

  final settings = SettingsBloc(paths);
  settings.add(const SettingsLoadRequested());
  // Настройки нужны блокам загрузок и библиотеки уже в конструкторе,
  // поэтому дожидаемся первого состояния из хранилища.
  await settings.loaded;

  L localizations() {
    final code = settings.state.locale;
    return lookupL(code == null ? _systemLocale() : Locale(code));
  }

  // Окно ставим до того, как оно появится на экране: иначе пользователь
  // увидит, как оно прыгает из одного положения в другое.
  await windowManager.ensureInitialized();
  final window = WindowState(
    store: JsonStore(paths.windowStateFile),
    controller: const ManagedWindowController(),
  );
  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      title: 'Evaporate',
      minimumSize: const Size(
        WindowGeometry.minWidth,
        WindowGeometry.minHeight,
      ),
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
      backgroundColor: Platform.isWindows ? null : Colors.transparent,
    ),
    () async {
      // macOS сохраняет нативные тень/скругление NSWindow, но без кнопок.
      if (!Platform.isMacOS) await windowManager.setAsFrameless();
      await window.restore(settings.state.windowStart);
    },
  );
  // Значок в трее ставим всегда: без него свёрнутое при запуске окно
  // было бы ничем не открыть, а режим запуска можно поменять на ходу.
  final tray = AppTray(localizations: localizations);
  try {
    await tray.install();
  } on Object {
    // Отказ трея не должен оставлять стартовавшее свёрнутым приложение
    // без способа открыть окно.
    await windowManager.show();
  }
  // Пишем всегда, даже когда восстановление выключено: включив его позже,
  // пользователь получит осмысленные значения, а не размер по умолчанию.
  WindowStateSaver(window).attach();

  // Разрешение у системы не спрашиваем на старте: это делает пользователь
  // кнопкой в настройках, чтобы диалог не выскакивал при первом запуске.
  final notifications = SystemNotificationService(localizations: localizations);
  await notifications.initialize();

  final library = LibraryBloc(
    paths: paths,
    settings: settings,
    notifications: notifications,
    localizations: localizations,
  );
  library.add(const LibraryLoadRequested());

  final downloads = DownloadsBloc(
    paths: paths,
    library: library,
    settings: settings,
    notifications: notifications,
    localizations: localizations,
  );
  // Движок поднимается в фоне: даже если он не поднимется, приложение
  // должно открыться — библиотекой и сейвами можно пользоваться.
  downloads.add(const DownloadEngineStartRequested());

  final gamepad = GamepadService(binding: settings.state.gamepad);
  // Отсутствие геймпада не должно мешать запуску — сервис это переживает сам.
  unawaited(gamepad.start());

  // В фоне и без ожидания: сеть может не ответить, а приложение должно
  // открыться сразу. Молчим и при ошибке — недоступный GitHub не повод
  // встречать пользователя сообщением.
  if (settings.state.checkUpdates) {
    unawaited(_announceUpdate(notifications, settings, localizations()));
  }

  runApp(
    EvaporateApp(
      settings: settings,
      library: library,
      downloads: downloads,
      gamepad: gamepad,
      notifications: notifications,
      tray: tray,
    ),
  );
}

class EvaporateApp extends StatefulWidget {
  const EvaporateApp({
    super.key,
    required this.settings,
    required this.library,
    required this.downloads,
    required this.gamepad,
    required this.notifications,
    this.tray,
  });

  final SettingsBloc settings;
  final LibraryBloc library;
  final DownloadsBloc downloads;
  final GamepadService gamepad;
  final NotificationService notifications;
  final AppTray? tray;

  @override
  State<EvaporateApp> createState() => _EvaporateAppState();
}

class _EvaporateAppState extends State<EvaporateApp> {
  @override
  void dispose() {
    unawaited(widget.tray?.dispose().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final library = widget.library;
    final downloads = widget.downloads;
    final gamepad = widget.gamepad;
    final notifications = widget.notifications;
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
        child: BlocConsumer<SettingsBloc, AppSettings>(
          listenWhen: (before, after) => before.locale != after.locale,
          listener: (context, settings) {
            unawaited(widget.tray?.updateMenu().catchError((Object _) {}));
            if (notifications is SystemNotificationService) {
              unawaited(notifications.initialize());
            }
          },
          buildWhen: (before, after) =>
              before.themeMode != after.themeMode ||
              before.locale != after.locale,
          builder: (context, settings) => MaterialApp(
            title: 'Evaporate',
            debugShowCheckedModeBanner: false,
            theme: EvaporateTheme.light(),
            darkTheme: EvaporateTheme.dark(),
            themeMode: settings.themeMode,
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            builder: (context, child) => AppWindowFrame(child: child!),
            // null означает «взять язык системы»: MaterialApp сам
            // подберёт ближайший из поддерживаемых.
            locale: settings.locale == null ? null : Locale(settings.locale!),
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
  L l,
) async {
  try {
    final release = await UpdateCheck().latest();
    if (release == null) return;
    if (!settings.state.systemNotifications) return;
    await notifications.show(
      AppNotification(
        title: l.newVersionOut(release.version),
        body: l.updateAvailableBody,
        kind: NotificationKind.test,
      ),
    );
  } on Object {
    // Проверка обновлений — удобство, а не обязанность: недоступная сеть
    // не должна ничем оборачиваться для пользователя.
  }
}

/// Язык системы, приведённый к поддерживаемому.
///
/// `lookupL` падает на незнакомой локали, а система вполне может сообщить
/// язык, на который приложение не переведено.
Locale _systemLocale() {
  final system = PlatformDispatcher.instance.locale;
  final supported = L.supportedLocales.map((l) => l.languageCode);
  return supported.contains(system.languageCode)
      ? Locale(system.languageCode)
      : L.supportedLocales.first;
}
