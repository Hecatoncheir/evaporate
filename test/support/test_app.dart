import 'dart:async';
import 'dart:io';

import 'package:evaporate/bloc/download_history/download_history_bloc.dart';
import 'package:evaporate/bloc/downloads/downloads_bloc.dart';
import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/bloc/saves/saves_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/bloc/update/update_bloc.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/core/json_store.dart';
import 'package:evaporate/input/gamepad_service.dart';
import 'package:evaporate/l10n/app_localizations.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/services/launch/drop_import.dart';
import 'package:evaporate/services/notifications/notification_service.dart';
import 'package:evaporate/services/saves/save_path_finder.dart';
import 'package:evaporate/services/system/desktop_entry.dart';
import 'package:evaporate/services/system/update_check.dart';
import 'package:evaporate/ui/shell.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:evaporate/ui/widgets/interface_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamepads/gamepads.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'recording_notifications.dart';
import 'temp_dir.dart';

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
/// Разбор сброшенного по одному имени, без диска: папка — то, у чего нет
/// расширения, `.torrent` — раздача, остальное неподходящее.
Future<List<DropCandidate>> dropByName(Iterable<String> paths) async => [
  for (final path in paths)
    if (p.extension(path).toLowerCase() == '.torrent')
      DropCandidate(
        path: path,
        kind: DropKind.torrent,
        title: p.basenameWithoutExtension(path),
      )
    else if (p.extension(path).isEmpty)
      DropCandidate(
        path: path,
        kind: DropKind.folder,
        title: p.basename(path),
        executablePath: p.join(path, 'game'),
      )
    else
      DropCandidate(
        path: path,
        kind: DropKind.unsupported,
        title: p.basename(path),
      ),
];

class TestHarness {
  TestHarness(
    this.tmp, {
    List<SaveRoot> Function()? saveRoots,
    Future<List<DropCandidate>> Function(Iterable<String>)? inspectDrop,
  }) : paths = AppPaths.custom(
         dataDir: p.join(tmp.path, 'data'),
         defaultInstallDir: p.join(tmp.path, 'games'),
       ),
       gamepadEvents = StreamController<NormalizedGamepadEvent>.broadcast() {
    settings = SettingsBloc(paths, store: _WidgetLibraryStore());
    library = LibraryBloc(
      store: _libraryStore,
      automaticMetadata: false,
      paths: paths,
      settings: settings,
      // Разбор сброшенного ходит по диску, а настоящий файловый I/O внутри
      // `testWidgets` не завершается никогда — та же ловушка, что и с
      // `saveRoots`. Здесь решают по имени; сам разбор проверен отдельно,
      // на настоящих файлах и без окна.
      inspectDrop: inspectDrop ?? dropByName,
    );
    saves = SavesBloc(
      paths: paths,
      library: library,
      settings: settings,
      store: _WidgetLibraryStore(),
      legacyStore: _WidgetLibraryStore(),
      notifications: notifications,
      // Выход из игры запускает обход папок в поисках следов её работы:
      // настоящий файловый ввод-вывод внутри testWidgets не завершается.
      // Тест, которому подсказки нужны, задаёт корни сам и крутит обход
      // через `runAsync`.
      saveRoots: saveRoots ?? () => const [],
      // То же с вопросом «есть ли папка правила»: ответ без ожидания диска.
      pathExists: (path) async =>
          Directory(path).existsSync() || File(path).existsSync(),
    );
    downloads = DownloadsBloc(
      paths: paths,
      library: library,
      settings: settings,
      notifications: notifications,
    );
    nav = NavigationBloc();
    // Без сети и без домашней папки: настоящий запрос к GitHub в прогоне
    // ни к чему, а файловый ввод-вывод записи в меню внутри `testWidgets`
    // не завершается.
    update = UpdateBloc(
      check: UpdateCheck(currentVersion: '0.1.0', fetch: (uri) async => '{}'),
      desktop: DesktopEntry(
        executablePath: '/tmp/evaporate',
        environment: const {},
      ),
    );
    history = DownloadHistoryBloc(
      tasks: downloads.stream.map((state) => state.tasks).distinct(),
    );
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
      await deleteTempDir(dir);
    } on FileSystemException {
      // Фоновая запись могла успеть создать файл — для теста это неважно.
    }
  }

  final Directory tmp;
  final AppPaths paths;
  final _libraryStore = _WidgetLibraryStore();

  /// Кладёт игру в библиотеку такой, как если бы она такой лежала на
  /// диске, — см. `seedGame` в `library_seed.dart`. Событие загрузки
  /// обработается на ближайшем `pump`.
  void seedGame(Game game) {
    _libraryStore.data = {
      'version': 1,
      'games': [
        for (final item in library.state.games)
          (item.id == game.id ? game : item).toJson(),
      ],
    };
    library.add(const LibraryLoadRequested());
  }

  /// Уведомления в тестах никуда не уходят — только записываются.
  final RecordingNotificationService notifications =
      RecordingNotificationService();

  late final SettingsBloc settings;
  late final LibraryBloc library;
  late final SavesBloc saves;
  late final DownloadsBloc downloads;
  late final GamepadService gamepad;
  late final NavigationBloc nav;
  late final DownloadHistoryBloc history;
  late final UpdateBloc update;
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
    bool motion = false,
  }) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: settings),
        BlocProvider.value(value: library),
        BlocProvider.value(value: saves),
        BlocProvider.value(value: downloads),
        BlocProvider.value(value: nav),
        BlocProvider.value(value: history),
        BlocProvider.value(value: update),
      ],
      child: MultiProvider(
        providers: [
          Provider.value(value: gamepad),
          Provider<NotificationService>.value(value: notifications),
        ],
        child: MaterialApp(
          // Обычные тесты взаимодействия не крутят бесконечный декоративный
          // тикер. Тесты эффектов включают его явно и прокручивают
          // ограниченное число кадров.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: !motion),
            child:
                builder?.call(context, InterfaceScale(child: child!)) ??
                InterfaceScale(child: child!),
          ),
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
    await saves.close();
    await library.close();
    await settings.close();
    await nav.close();
    await history.close();
    await update.close();
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
