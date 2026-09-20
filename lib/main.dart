import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'bloc/downloads/downloads_bloc.dart';
import 'bloc/library/library_bloc.dart';
import 'bloc/logging_observer.dart';
import 'bloc/navigation/navigation_bloc.dart';
import 'bloc/saves/saves_bloc.dart';
import 'bloc/settings/settings_bloc.dart';
import 'core/app_paths.dart';
import 'core/json_store.dart';
import 'input/gamepad_service.dart';
import 'l10n/app_localizations.dart';
import 'models/app_settings.dart';
import 'services/notifications/notification_service.dart';
import 'services/notifications/system_notification_service.dart';
import 'services/system/app_log.dart';
import 'services/system/app_shutdown.dart';
import 'services/system/app_tray.dart';
import 'services/system/managed_window.dart';
import 'services/system/proxy_http_overrides.dart';
import 'services/system/update_check.dart';
import 'services/system/update_installer.dart';
import 'services/system/window_mode_watch.dart';
import 'services/system/window_state.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';
import 'ui/widgets/interface_scale.dart';
import 'ui/widgets/window_frame.dart';

/// Запуск приложения — список шагов по порядку.
///
/// Порядок здесь значим почти везде, и каждый шаг объясняет свой: журнал
/// заводится раньше всего, настройки читаются до блоков, окно ставится до
/// показа, значок в трее ставится всегда.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final paths = await AppPaths.init();
  await _startLog(paths);

  final settings = SettingsBloc(paths);
  settings.add(const SettingsLoadRequested());
  // Настройки нужны блокам загрузок и библиотеки уже в конструкторе,
  // поэтому дожидаемся первого состояния из хранилища.
  await settings.loaded;

  final stopProxyRouting = await _routeThroughProxy(settings);

  L localizations() {
    final code = settings.state.locale;
    return lookupL(code == null ? _systemLocale() : Locale(code));
  }

  final window = await _prepareWindow(paths, settings.state);

  // Что должно успеть лечь на диск, прежде чем процесс закончится. Список
  // наполняется по мере того, как появляются его владельцы, а порядок в нём
  // обратный порядку создания: сначала останавливаем, потом отпускаем.
  final shutdownSteps = <ShutdownStep>[stopProxyRouting, AppLog.instance.flush];
  final closeHandler = WindowCloseHandler(AppShutdown(shutdownSteps));
  await closeHandler.attach();

  final tray = await _installTray(localizations, closeHandler.quit);

  final windowMode = await _watchWindow(window, shutdownSteps);

  // Разрешение у системы не спрашиваем на старте: это делает пользователь
  // кнопкой в настройках, чтобы диалог не выскакивал при первом запуске.
  final notifications = SystemNotificationService(localizations: localizations);
  await notifications.initialize();

  final library = LibraryBloc(
    paths: paths,
    settings: settings,
    localizations: localizations,
  );
  library.add(const LibraryLoadRequested());

  // После библиотеки: блок сохранений подписывается на её события и
  // ставит ей хук «снять сейв перед запуском».
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
  );
  // Движок поднимается в фоне: даже если он не поднимется, приложение
  // должно открыться — библиотекой и сейвами можно пользоваться.
  downloads.add(const DownloadEngineStartRequested());

  // Порядок важен: движок гасим раньше сохранений и библиотеки, потому что
  // его задачи ещё правят её игры; сохранения — раньше библиотеки, они на
  // неё подписаны;
  // настройки — последними: на них смотрят все.
  shutdownSteps.addAll([
    downloads.close,
    saves.close,
    library.close,
    settings.close,
  ]);

  final gamepad = GamepadService(binding: settings.state.gamepad);
  shutdownSteps.add(() async => gamepad.dispose());
  shutdownSteps.add(tray.dispose);
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
      saves: saves,
      downloads: downloads,
      gamepad: gamepad,
      notifications: notifications,
      windowMode: windowMode,
      tray: tray,
    ),
  );
}

/// Заводит журнал и сводит в него чужие жалобы.
///
/// Раньше всего остального: смысл журнала в том, чтобы застать и то, что
/// ломается на старте.
Future<void> _startLog(AppPaths paths) async {
  AppLog.instance = AppLog(
    path: paths.logFile,
    previousPath: paths.previousLogFile,
  );
  AppLog.instance.write('запуск ${AppVersion.current}');
  // Здесь же, до первого блока: иначе первые же их сбои прошли бы мимо
  // журнала — а больше о них узнать неоткуда, консоли у человека нет.
  Bloc.observer = const LoggingBlocObserver();
  // Помощник обновления работает, когда приложения уже нет, и пишет в свой
  // файл. Забираем написанное сюда — иначе о неудавшейся замене не узнал бы
  // никто, кроме того, кто полез бы искать файл руками.
  await UpdateInstaller.collectLog(paths.dataDir);

  // Движок загрузок жалуется через `logging`, и до сих пор его жалобы не
  // доходили никуда: задача часами висела «активной», а о недоступном
  // трекере или не поднявшемся DHT не было сказано ни слова.
  Logger.root.level = Level.WARNING;
  Logger.root.onRecord.listen(
    (record) => AppLog.instance.write(
      '${record.loggerName}: ${record.message}',
      record.error,
    ),
  );
}

/// Пускает весь HTTP приложения через прокси и следит за его сменой.
/// Возвращает шаг завершения: отписаться от изменений настроек.
///
/// Прокси применяется перехватом создания клиента, а не настройкой каждого:
/// объявление трекеру внутри библиотеки заводит клиента само, и наши
/// настройки мимо него проходят. Дотянуться до него больше неоткуда.
Future<ShutdownStep> _routeThroughProxy(SettingsBloc settings) async {
  final routing = ProxyHttpOverrides();
  await routing.apply(settings.state.proxy);
  HttpOverrides.global = routing;
  final changes = settings.stream
      .map((state) => state.proxy)
      .distinct()
      .listen((proxy) => unawaited(routing.apply(proxy)));
  return changes.cancel;
}

/// Готовит окно до того, как оно появится на экране: иначе пользователь
/// увидит, как оно прыгает из одного положения в другое.
/// Приставляет к окну обоих наблюдателей: того, кто запоминает положение,
/// и того, кто следит за развёрнутостью.
///
/// Положение пишем всегда, даже когда восстановление выключено: включив его
/// позже, пользователь получит осмысленные значения, а не размер по
/// умолчанию. Развёрнутость нужна рамке, но следит за ней служба — у окна и
/// без рамки уже двое слушателей, и третьему в виджете не место.
Future<WindowModeWatch> _watchWindow(
  WindowState window,
  List<ShutdownStep> shutdownSteps,
) async {
  final saver = WindowStateSaver(window)..attach();
  shutdownSteps.add(saver.flush);
  final mode = WindowModeWatch();
  await mode.attach();
  return mode;
}

Future<WindowState> _prepareWindow(AppPaths paths, AppSettings settings) async {
  await windowManager.ensureInitialized();
  final window = WindowState(
    store: JsonStore(paths.windowStateFile),
    controller: const ManagedWindowController(),
  );
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      title: 'Evaporate',
      minimumSize: Size(WindowGeometry.minWidth, WindowGeometry.minHeight),
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
      // Прозрачный фон на всех системах: углы окна режет само приложение
      // (`AppWindowFrame`), и за вырезанным углом должен быть виден стол,
      // а не подложка окна.
      backgroundColor: AppColors.transparent,
    ),
    () async {
      // macOS сохраняет нативные тень/скругление NSWindow, но без кнопок.
      if (!Platform.isMacOS) await windowManager.setAsFrameless();
      await window.restore(settings.windowStart);
    },
  );
  return window;
}

/// Ставит значок в трее — всегда, при любом режиме запуска.
///
/// Без него свёрнутое при запуске окно было бы ничем не открыть, а режим
/// запуска можно поменять на ходу. «Выход» из трея уходит тем же путём, что
/// и закрытие окна.
Future<AppTray> _installTray(
  L Function() localizations,
  Future<void> Function() onQuit,
) async {
  final tray = AppTray(localizations: localizations, onQuit: onQuit);
  try {
    await tray.install();
  } on Object {
    // Отказ трея не должен оставлять стартовавшее свёрнутым приложение
    // без способа открыть окно.
    await windowManager.show();
  }
  return tray;
}

class EvaporateApp extends StatefulWidget {
  const EvaporateApp({
    super.key,
    required this.settings,
    required this.library,
    required this.saves,
    required this.downloads,
    required this.gamepad,
    required this.notifications,
    required this.windowMode,
    this.tray,
  });

  final SettingsBloc settings;
  final LibraryBloc library;
  final SavesBloc saves;
  final DownloadsBloc downloads;
  final GamepadService gamepad;
  final NotificationService notifications;
  final WindowModeWatch windowMode;
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
    final saves = widget.saves;
    final downloads = widget.downloads;
    final gamepad = widget.gamepad;
    final notifications = widget.notifications;
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: settings),
        BlocProvider.value(value: library),
        BlocProvider.value(value: saves),
        BlocProvider.value(value: downloads),
        BlocProvider(create: (_) => NavigationBloc(library: library)),
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
            themeMode: settings.themeMode.material,
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            builder: (context, child) => AppWindowFrame(
              mode: widget.windowMode,
              child: InterfaceScale(child: child!),
            ),
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
        kind: NotificationKind.updateAvailable,
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
