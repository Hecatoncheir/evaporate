import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app_services.dart';
import 'bloc/download_history/download_history_bloc.dart';
import 'bloc/logging_observer.dart';
import 'bloc/navigation/navigation_bloc.dart';
import 'bloc/settings/settings_bloc.dart';
import 'core/app_paths.dart';
import 'core/json_store.dart';
import 'l10n/app_localizations.dart';
import 'models/app_settings.dart';
import 'services/notifications/notification_service.dart';
import 'services/notifications/system_notification_service.dart';
import 'services/system/app_log.dart';
import 'services/system/app_shutdown.dart';
import 'services/system/app_tray.dart';
import 'services/system/launch_home.dart';
import 'services/system/managed_window.dart';
import 'services/system/native_tray_host.dart';
import 'services/system/proxy_http_overrides.dart';
import 'services/system/single_instance.dart';
import 'services/system/smoke_run.dart';
import 'services/system/update_check.dart';
import 'services/system/update_installer.dart';
import 'services/system/window_mode_watch.dart';
import 'services/system/window_state.dart';
import 'ui/ev/app/app_theme.dart';
import 'ui/ev/app/ev_app_scope.dart';
import 'ui/ev/sound/ev_sound.dart';
import 'ui/ev/sound/soloud_out.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';
import 'ui/window/app_window_frame.dart';
import 'ui/window/interface_scale.dart';

/// Запуск приложения — список шагов по порядку.
///
/// Порядок здесь значим почти везде, и каждый шаг объясняет свой: журнал
/// заводится раньше всего, настройки читаются до блоков, окно ставится до
/// показа, значок в трее ставится всегда.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final smoke = SmokeRun.requested(args) ? await SmokeRun.prepare() : null;
  // Дом — временный у дымового запуска и заданный `--home=` у запуска на
  // копии данных; иначе системная папка.
  final paths = await AppPaths.init(home: smoke?.home.path ?? launchHome(args));
  final instance = await _claimInstance(paths);
  await _startLog(paths);

  final settings = SettingsBloc(paths);
  settings.add(const SettingsLoadRequested());
  // Настройки нужны блокам загрузок и библиотеки уже в конструкторе,
  // поэтому дожидаемся первого состояния из хранилища.
  await settings.loaded;

  final (proxyRouting, stopProxyRouting) = await _routeThroughProxy(settings);

  L localizations() {
    final code = settings.state.appearance.locale;
    return lookupL(code == null ? _systemLocale() : Locale(code));
  }

  final window = await _prepareWindow(paths, settings.state);

  // Что должно успеть лечь на диск, прежде чем процесс закончится. Список
  // наполняется по мере того, как появляются его владельцы, и шаги идут в
  // его порядке; журнал дописывается последним — после всех, кто в него
  // пишет, включая сбои самих шагов.
  final shutdownSteps = <ShutdownStep>[stopProxyRouting];
  final (closeHandler, shutdown) = await _handleClose(shutdownSteps);

  final tray = await _installTray(localizations, closeHandler.quit);

  final windowMode = await _watchWindow(window, shutdownSteps);

  final services = await AppServices.bootstrap(
    paths: paths,
    settings: settings,
    localizations: localizations,
    shutdownSteps: shutdownSteps,
    proxyRouting: proxyRouting.routing,
  );
  // Замок — под конец: пока идут шаги, второй экземпляр не нужен.
  shutdownSteps.addAll([tray.dispose, instance.release, AppLog.instance.flush]);

  runApp(
    EvaporateApp(
      settings: settings,
      services: services,
      windowMode: windowMode,
      tray: tray,
      // Звук прототипа включён сразу. Не завёлся движок (нет устройства,
      // как в CI) — окно просто молчит: `EvSoLoudOut` гасит отказ сам.
      sound: EvSound(out: EvSoLoudOut(), enabled: true),
    ),
  );
  if (smoke != null) unawaited(_smokeTest(smoke, paths, shutdown, tray));
}

/// Дымовой запуск: проверки после первого кадра и выход с их итогом.
///
/// Выход своими руками, а не закрытием окна: код возврата — весь ответ
/// прогону, а штатное закрытие на macOS и Linux кончается нулём всегда.
Future<void> _smokeTest(
  SmokeRun smoke,
  AppPaths paths,
  AppShutdown shutdown,
  AppTray tray,
) async {
  final code = await smoke.check(
    firstFrame: WidgetsBinding.instance.waitUntilFirstFrameRasterized,
    shutdown: shutdown.run,
    dataDir: paths.dataDir,
    logFile: paths.logFile,
    // На Linux значку нужна панель, которая его примет: под `xvfb` в CI её
    // нет, как нет и в GNOME без расширения, и это не поломка сборки.
    trayShown: Platform.isLinux ? null : () => tray.isInstalled,
  );
  exit(code);
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
  // И то, что падает мимо блоков: сборка виджетов, брошенные `Future`.
  AppLog.captureUnhandled(() => AppLog.instance);
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
///
/// Прокси применяется перехватом создания клиента, а не настройкой каждого:
/// объявление трекеру внутри библиотеки заводит клиента само, и наши
/// настройки мимо него проходят. Дотянуться до него больше неоткуда.
///
/// Возвращает и сам перехват: его `routing` берут загрузки, чтобы сказать
/// человеку, если прокси отвалился. Шаг завершения — отписка от настроек.
Future<(ProxyHttpOverrides, ShutdownStep)> _routeThroughProxy(
  SettingsBloc settings,
) async {
  final routing = ProxyHttpOverrides();
  await routing.apply(settings.state.proxy);
  HttpOverrides.global = routing;
  final changes = settings.stream
      .map((state) => state.proxy)
      .distinct()
      .listen((proxy) => unawaited(routing.apply(proxy)));
  Future<void> stop() async {
    routing.stopRetrying();
    await changes.cancel();
  }

  return (routing, stop);
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
      await window.restore(settings.startup.windowStart);
    },
  );
  return window;
}

/// Перехватывает закрытие окна: сначала [steps], потом конец процесса.
///
/// Сорвавшийся шаг уходит в журнал: показать его уже некому — окно
/// закрывается, — а без журнала от него не осталось бы и следа.
Future<(WindowCloseHandler, AppShutdown)> _handleClose(
  List<ShutdownStep> steps,
) async {
  final shutdown = AppShutdown(
    steps,
    onError: (error) => AppLog.instance.write('завершение', error),
  );
  final handler = WindowCloseHandler(shutdown);
  await handler.attach();
  return (handler, shutdown);
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
  final tray = AppTray(
    host: NativeTrayHost(),
    localizations: localizations,
    onQuit: onQuit,
  );
  try {
    await tray.install();
  } on Object catch (error) {
    // Отказ трея не должен оставлять стартовавшее свёрнутым приложение
    // без способа открыть окно. И молчать о нём нельзя: пропавший значок
    // иначе не объяснить ничем.
    AppLog.instance.write('значок в трее', error);
    await windowManager.show();
  }
  return tray;
}

/// Приложение: блоки и службы над `MaterialApp`, каркас — домашним экраном.
///
/// Схема одна — тёмная: дневной у прототипа нет (0013); выбор схемы в
/// файле настроек остался ради совместимости и ни на что не влияет.
/// Эффекты и звук прототипа (`EvAppScope`) лежат над навигатором: их
/// видят и каркас, и всё, что открывается поверх него.
class EvaporateApp extends StatefulWidget {
  const EvaporateApp({
    super.key,
    required this.settings,
    required this.services,
    required this.windowMode,
    this.tray,
    this.sound,
  });

  final SettingsBloc settings;

  /// Блоки и службы, поднятые `AppServices.bootstrap`, — одним значением:
  /// по одной штуке они шли сюда шестью параметрами, и каждый новый блок
  /// уровня приложения добавлял седьмой.
  final AppServices services;

  final WindowModeWatch windowMode;
  final AppTray? tray;

  /// Звук прототипа — один на приложение, поэтому заводится в `main`, а
  /// не в дереве: пересборка не должна заново поднимать звуковой движок.
  final EvSound? sound;

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
    final services = widget.services;
    final notifications = services.notifications;
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: widget.settings),
        BlocProvider.value(value: services.library),
        BlocProvider.value(value: services.saves),
        BlocProvider.value(value: services.downloads),
        BlocProvider(create: (_) => NavigationBloc(library: services.library)),
        BlocProvider.value(value: services.update),
        // Истории скоростей — одна на приложение: на задачу смотрят и
        // карточка на загрузках, и страница игры, живущие разом.
        BlocProvider(
          create: (_) => DownloadHistoryBloc(
            tasks: services.downloads.stream
                .map((state) => state.tasks)
                .distinct(),
          ),
        ),
      ],
      // Сервис ввода состояния не имеет — его внедряет обычный Provider,
      // на котором flutter_bloc и так построен.
      child: MultiProvider(
        providers: [
          Provider.value(value: services.gamepad),
          Provider<NotificationService>.value(value: notifications),
        ],
        child: BlocConsumer<SettingsBloc, AppSettings>(
          listenWhen: (before, after) =>
              before.appearance.locale != after.appearance.locale,
          listener: (context, settings) {
            unawaited(widget.tray?.updateMenu().catchError((Object _) {}));
            if (notifications is SystemNotificationService) {
              unawaited(notifications.initialize());
            }
          },
          buildWhen: (before, after) => _locale(before) != _locale(after),
          builder: (context, settings) => MaterialApp(
            title: 'Evaporate',
            debugShowCheckedModeBanner: false,
            theme: evaporateAppTheme(),
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            builder: (context, child) => EvAppScope(
              sound: widget.sound,
              child: AppWindowFrame(
                mode: widget.windowMode,
                child: InterfaceScale(child: child!),
              ),
            ),
            // null означает «взять язык системы»: MaterialApp сам
            // подберёт ближайший из поддерживаемых.
            locale: _locale(settings),
            home: const AppShell(),
          ),
        ),
      ),
    );
  }
}

/// То из настроек, от чего зависит сам `MaterialApp`, — язык.
///
/// Одной функцией и для сборки, и для сравнения: перестраивать приложение
/// целиком стоит только на нём, и сравнивать надо ровно то, что отдаётся
/// в `MaterialApp`.
Locale? _locale(AppSettings settings) {
  final code = settings.appearance.locale;
  return code == null ? null : Locale(code);
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

/// Берёт замок экземпляра, а если приложение уже работает — просит его
/// показать окно и завершает этот процесс.
///
/// Раньше журнала: второй экземпляр не должен писать ни в него, ни
/// куда-либо ещё (`SingleInstance`).
Future<SingleInstance> _claimInstance(AppPaths paths) async {
  final instance = await SingleInstance.acquire(
    paths.dataDir,
    onShowRequested: _showWindow,
  );
  return instance ?? exit(0);
}

/// Второй экземпляр просит показать окно: человек щёлкнул ярлык, а окно
/// свёрнуто в трей или спрятано за другими.
///
/// Просьба может прийти раньше, чем окно готово, — тогда оно покажется
/// само, как задумано режимом запуска, а ошибку глотаем.
void _showWindow() {
  unawaited(
    windowManager
        .show()
        .then((_) => windowManager.focus())
        .catchError((Object _) {}),
  );
}
