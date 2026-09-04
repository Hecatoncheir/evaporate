import 'dart:async';
import 'dart:io';

import 'package:evaporate/bloc/downloads/downloads_bloc.dart';
import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/core/json_store.dart';
import 'package:evaporate/l10n/app_localizations.dart';
import 'package:evaporate/input/gamepad_service.dart';
import 'package:evaporate/services/notifications/notification_service.dart';
import 'package:evaporate/ui/shell.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamepads/gamepads.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';

import 'recording_notifications.dart';

/// Файловый I/O проверяется отдельными тестами. В fake-async виджетов
/// он не завершается, а закрытие библиотеки теперь дожидается всех записей.
class _WidgetLibraryStore extends JsonStore {
  _WidgetLibraryStore() : super('unused');
  Map<String, dynamic>? data;

  @override
  Future<Map<String, dynamic>?> read() async => data;

  @override
  Future<void> write(Map<String, dynamic> value) async {
    data = value;
  }
}

/// Собранное приложение со всеми блоками и подменённым потоком геймпада —
/// так события контроллера можно эмулировать без железа.
///
/// Конструктор синхронный и обязан вызываться **внутри** `testWidgets`:
/// Bloc обрабатывает события через внутренний поток, и подписка запоминает
/// зону, в которой была создана. Блок, собранный в `setUp`, доставлял бы
/// события мимо фейкового времени теста, и `pump` их не прокручивал бы.
/// Временную папку, наоборот, готовим снаружи — реальный файловый I/O
/// внутри `testWidgets` не завершается никогда.
class TestHarness {
  TestHarness(this.tmp)
    : paths = AppPaths.custom(
        dataDir: p.join(tmp.path, 'data'),
        defaultInstallDir: p.join(tmp.path, 'games'),
      ),
      gamepadEvents = StreamController<NormalizedGamepadEvent>.broadcast() {
    settings = SettingsBloc(paths);
    library = LibraryBloc(
      store: _WidgetLibraryStore(),
      automaticMetadata: false,
      paths: paths,
      settings: settings,
      notifications: notifications,
      // Выход из игры запускает обход папок в поисках следов её работы:
      // настоящий файловый ввод-вывод внутри testWidgets не завершается.
      saveRoots: () => const [],
    );
    downloads = DownloadsBloc(
      paths: paths,
      library: library,
      settings: settings,
      notifications: notifications,
    );
    nav = NavigationBloc();
    gamepad = GamepadService(
      source: gamepadEvents.stream,
      // Автоповтор проверяется юнит-тестами сервиса. Здесь он только мешает:
      // pumpAndSettle крутил бы время, пока таймер повторов не иссякнет.
      repeatDelay: const Duration(hours: 1),
      repeatInterval: const Duration(hours: 1),
    );
    // gamepad.start() намеренно не вызываем: события подаём через handleEvent.
  }

  static Future<Directory> makeTempDir() =>
      Directory.systemTemp.createTemp('evaporate_ui_');

  static Future<void> removeTempDir(Directory dir) async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } on FileSystemException {
      // Фоновая запись могла успеть создать файл — для теста это неважно.
    }
  }

  final Directory tmp;
  final AppPaths paths;

  /// Уведомления в тестах никуда не уходят — только записываются.
  final RecordingNotificationService notifications =
      RecordingNotificationService();

  late final SettingsBloc settings;
  late final LibraryBloc library;
  late final DownloadsBloc downloads;
  late final GamepadService gamepad;
  late final NavigationBloc nav;
  final StreamController<NormalizedGamepadEvent> gamepadEvents;

  /// Добавляет игру событием и возвращает её идентификатор — событие
  /// ничего не возвращает, а тестам удобно ссылаться на игру.
  String addGame({
    required String title,
    GameSource? source,
    String? installDir,
    GameStatus status = GameStatus.notInstalled,
  }) {
    final id = const Uuid().v4();
    library.add(
      GameAdded(
        id: id,
        title: title,
        source: source,
        installDir: installDir,
        status: status,
      ),
    );
    return id;
  }

  Widget buildApp({
    ThemeData? theme,
    Locale? locale,
    TransitionBuilder? builder,
  }) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: settings),
        BlocProvider.value(value: library),
        BlocProvider.value(value: downloads),
        BlocProvider.value(value: nav),
      ],
      child: MultiProvider(
        providers: [
          Provider.value(value: gamepad),
          Provider<NotificationService>.value(value: notifications),
        ],
        child: MaterialApp(
          builder: builder,
          theme: theme ?? EvaporateTheme.dark(),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          // По умолчанию русский: иначе окружение выбрало бы системный
          // язык, и тесты зависели бы от настроек машины.
          locale: locale ?? const Locale('ru'),
          home: const AppShell(),
        ),
      ),
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    ThemeData? theme,
    Locale? locale,
  }) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildApp(theme: theme, locale: locale));
    await tester.pumpAndSettle();
    // Отложенная запись библиотеки на диск.
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Нажатие и отпускание кнопки геймпада.
  Future<void> tapButton(WidgetTester tester, GamepadButton button) async {
    gamepad.handleEvent(buttonEvent(button, 1));
    await tester.pump();
    gamepad.handleEvent(buttonEvent(button, 0));
    await tester.pump();
    await tester.pumpAndSettle();
  }

  /// Отклоняет стик и возвращает его в центр — иначе удержание оставит
  /// висеть таймер автоповтора.
  Future<void> moveStick(
    WidgetTester tester,
    GamepadAxis axis,
    double value,
  ) async {
    gamepad.handleEvent(axisEvent(axis, value));
    await tester.pump();
    gamepad.handleEvent(axisEvent(axis, 0));
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> dispose() async {
    gamepad.dispose();
    await gamepadEvents.close();
    await downloads.close();
    await library.close();
    await settings.close();
    await nav.close();
  }
}

NormalizedGamepadEvent buttonEvent(GamepadButton button, double value) {
  return NormalizedGamepadEvent(
    gamepadId: 'test',
    timestamp: DateTime.now().millisecondsSinceEpoch,
    value: value,
    button: button,
    rawEvent: GamepadEvent(
      gamepadId: 'test',
      timestamp: DateTime.now().millisecondsSinceEpoch,
      type: KeyType.button,
      key: button.name,
      value: value,
    ),
  );
}

NormalizedGamepadEvent axisEvent(GamepadAxis axis, double value) {
  return NormalizedGamepadEvent(
    gamepadId: 'test',
    timestamp: DateTime.now().millisecondsSinceEpoch,
    value: value,
    axis: axis,
    rawEvent: GamepadEvent(
      gamepadId: 'test',
      timestamp: DateTime.now().millisecondsSinceEpoch,
      type: KeyType.analog,
      key: axis.name,
      value: value,
    ),
  );
}
