import 'dart:io';

import 'package:evaporate/bloc/downloads/downloads_bloc.dart';
import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/models/download_task.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/models/proxy_settings.dart';
import 'package:evaporate/services/download/integrity_check.dart';
import 'package:evaporate/services/system/proxy_http_overrides.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../support/fake_download_engine.dart';
import '../support/temp_dir.dart';
import '../support/wait_for_state.dart';

/// Что блок поручает движку по нажатиям человека: поставить в очередь,
/// приостановить, продолжить, снять, переставить, отдать файл раздачи.
///
/// Прежде движок заводился внутри блока и требовал живых раздач, поэтому
/// ни один из этих путей не исполнялся ни разу.
void main() {
  late Directory tmp;
  late AppPaths paths;
  late SettingsBloc settings;
  late LibraryBloc library;
  late DownloadsBloc downloads;
  late FakeDownloadEngine engine;
  late ValueNotifier<ProxyRouting> proxyRouting;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_downloads_');
    paths = AppPaths.custom(
      dataDir: p.join(tmp.path, 'data'),
      defaultInstallDir: p.join(tmp.path, 'games'),
    );
    settings = SettingsBloc(paths);
    library = LibraryBloc(
      automaticMetadata: false,
      paths: paths,
      settings: settings,
    );
    engine = FakeDownloadEngine();
    proxyRouting = ValueNotifier(ProxyRouting.direct);
    downloads = DownloadsBloc(
      paths: paths,
      library: library,
      settings: settings,
      engine: engine,
      proxyRouting: proxyRouting,
    );
  });

  tearDown(() async {
    await downloads.close();
    await library.persist();
    await library.close();
    await settings.close();
    try {
      await deleteTempDir(tmp);
    } on FileSystemException {
      // Остатки временной папки на результат теста не влияют.
    }
  });

  Future<LibraryState> waitForLibrary(bool Function(LibraryState) condition) =>
      waitForState(library, condition);

  Future<DownloadsState> waitForDownloads(
    bool Function(DownloadsState) condition,
  ) => waitForState(downloads, condition);

  /// Ждёт, пока движку поручат нужное: поручения идут через очередь
  /// событий блока, и к следующей строке теста они ещё не дошли.
  Future<void> waitForCall(String call) async {
    for (var i = 0; i < 200 && !engine.calls.contains(call); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(engine.calls, contains(call));
  }

  Future<Game> addedGame({String title = 'Игра'}) async {
    final id = const Uuid().v4();
    library.add(GameAdded(id: id, title: title));
    final state = await waitForLibrary((s) => s.gameById(id) != null);
    return state.gameById(id)!;
  }

  /// Игра, которую движок «качает».
  Future<Game> downloadingGame({String taskId = 'task-1'}) async {
    final game = await addedGame();
    library.add(
      GameDownloadStarted(
        game.id,
        const GameSource(
          kind: GameSourceKind.magnet,
          value: 'magnet:?xt=urn:btih:test',
        ),
        taskId,
      ),
    );
    final state = await waitForLibrary(
      (s) => s.gameById(game.id)?.status == GameStatus.downloading,
    );
    return state.gameById(game.id)!;
  }

  group('запрос загрузки', () {
    test('неготовый движок отвечает словами, а не тишиной', () async {
      final game = await addedGame();

      downloads.add(
        DownloadRequested(
          game: game,
          source: const GameSource(
            kind: GameSourceKind.magnet,
            value: 'magnet:?xt=urn:btih:abc',
          ),
        ),
      );
      final state = await waitForDownloads((s) => s.notice != null);

      expect(state.notice!.isError, isTrue);
      expect(
        engine.calls,
        isNot(contains('addMagnet magnet:?xt=urn:btih:abc -> ${tmp.path}')),
      );
    });

    test('magnet-ссылка уходит движку и связывается с игрой', () async {
      engine
        ..becomeReady()
        ..nextTaskId = 'task-7';
      final game = await addedGame();

      downloads.add(
        DownloadRequested(
          game: game,
          source: const GameSource(
            kind: GameSourceKind.magnet,
            value: 'magnet:?xt=urn:btih:abc',
          ),
        ),
      );
      final state = await waitForLibrary(
        (s) => s.gameById(game.id)?.downloadTaskId != null,
      );

      expect(state.gameById(game.id)!.downloadTaskId, 'task-7');
      expect(state.gameById(game.id)!.status, GameStatus.downloading);
      expect(
        engine.calls.first,
        startsWith('addMagnet magnet:?xt=urn:btih:abc'),
      );
    });

    // Исходный файл могут удалить, переименовать или воткнуть флешку с ним
    // обратно только завтра, а раздача должна пережить перезапуск.
    test('.torrent копируется к себе, и движок получает копию', () async {
      engine.becomeReady();
      final game = await addedGame();
      final source = p.join(tmp.path, 'раздача.torrent');
      await File(source).writeAsString('d4:infod');

      downloads.add(
        DownloadRequested(
          game: game,
          source: GameSource(kind: GameSourceKind.torrentFile, value: source),
        ),
      );
      await waitForLibrary((s) => s.gameById(game.id)?.downloadTaskId != null);

      final stored = p.join(paths.torrentsDir, '${game.id}.torrent');
      expect(File(stored).existsSync(), isTrue);
      expect(engine.calls.first, startsWith('addTorrentFile $stored'));
    });

    test('папку на диске качать нечего, и об этом говорят', () async {
      engine.becomeReady();
      final game = await addedGame();

      downloads.add(
        DownloadRequested(
          game: game,
          source: GameSource(kind: GameSourceKind.localFolder, value: tmp.path),
        ),
      );
      final state = await waitForDownloads((s) => s.notice != null);

      expect(state.notice!.isError, isTrue);
      expect(engine.calls, isEmpty);
    });

    test('отказ движка приходит сообщением, а не падением', () async {
      engine
        ..becomeReady()
        ..failure = Exception('порт занят');
      final game = await addedGame();

      downloads.add(
        DownloadRequested(
          game: game,
          source: const GameSource(
            kind: GameSourceKind.magnet,
            value: 'magnet:?xt=urn:btih:abc',
          ),
        ),
      );
      final state = await waitForDownloads((s) => s.notice != null);

      expect(state.notice!.isError, isTrue);
      expect(state.notice!.message, contains('порт занят'));
      expect(library.state.gameById(game.id)!.downloadTaskId, isNull);
    });
  });

  group('управление задачей', () {
    test('пауза останавливает задачу и метит игру', () async {
      final game = await downloadingGame();

      downloads.add(DownloadPauseRequested(game));
      final state = await waitForLibrary(
        (s) => s.gameById(game.id)?.status == GameStatus.paused,
      );

      expect(engine.calls, contains('pause task-1'));
      expect(state.gameById(game.id)!.status, GameStatus.paused);
    });

    test('продолжение возвращает игру в загрузку', () async {
      final game = await downloadingGame();
      downloads.add(DownloadPauseRequested(game));
      await waitForLibrary(
        (s) => s.gameById(game.id)?.status == GameStatus.paused,
      );

      downloads.add(DownloadResumeRequested(game));
      final state = await waitForLibrary(
        (s) => s.gameById(game.id)?.status == GameStatus.downloading,
      );

      expect(engine.calls, contains('resume task-1'));
      expect(state.gameById(game.id)!.status, GameStatus.downloading);
    });

    // Игра без задачи движку не принадлежит: поручать по `null` нечего.
    test('игра без задачи движка не беспокоит', () async {
      final game = await addedGame();

      downloads.add(DownloadPauseRequested(game));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(engine.calls, isEmpty);
    });

    test('отказ движка на паузе не меняет статус игры', () async {
      final game = await downloadingGame();
      engine.failure = Exception('задача не найдена');

      downloads.add(DownloadPauseRequested(game));
      final state = await waitForDownloads((s) => s.notice != null);

      expect(state.notice!.isError, isTrue);
      expect(
        library.state.gameById(game.id)!.status,
        GameStatus.downloading,
        reason: 'движок задачу не остановил — значит, она и не на паузе',
      );
    });

    test('отмена снимает задачу и отвязывает её от игры', () async {
      final game = await downloadingGame();

      downloads.add(DownloadCancelRequested(game));
      final state = await waitForLibrary(
        (s) => s.gameById(game.id)?.downloadTaskId == null,
      );

      expect(engine.calls, contains('remove task-1'));
      expect(state.gameById(game.id)!.status, isNot(GameStatus.downloading));
    });

    // Снять задачу надо в любом случае: иначе движок продолжил бы качать
    // то, от чего человек отказался.
    test('отмена доводится до конца и при отказе движка', () async {
      final game = await downloadingGame();
      engine.failure = Exception('движок молчит');

      downloads.add(DownloadCancelRequested(game));
      final state = await waitForLibrary(
        (s) => s.gameById(game.id)?.downloadTaskId == null,
      );

      expect(engine.calls, contains('remove task-1'));
      expect(state.gameById(game.id)!.downloadTaskId, isNull);
    });
  });

  group('конец загрузки', () {
    DownloadTask done(String id) => DownloadTask(
      id: id,
      name: 'Игра [RePack]',
      state: DownloadState.complete,
      dir: p.join(tmp.path, 'games'),
      files: [p.join(tmp.path, 'games', 'Игра', 'game.exe')],
      totalBytes: 2,
      completedBytes: 2,
    );

    // Хеши кусков сверяются при скачивании, но пропавший файл протокол
    // уже не заметит: игру объявили бы готовой, а запускать было бы
    // нечего.
    test('недосчитавшийся файл не делает игру установленной', () async {
      final game = await downloadingGame();
      engine.report = const IntegrityReport(
        checkedFiles: 2,
        missing: ['game.exe'],
      );

      downloads.add(EngineTasksChanged([done(game.downloadTaskId!)]));
      final state = await waitForLibrary(
        (s) => s.gameById(game.id)?.status == GameStatus.error,
      );

      expect(engine.calls, contains('verify task-1'));
      expect(state.gameById(game.id)!.lastError, isNotNull);
      // Сообщение идёт после записи библиотеки на диск, поэтому его ждут,
      // а не застают.
      final told = await waitForDownloads((s) => s.notice != null);
      expect(told.notice!.isError, isTrue);
    });

    test('целая раздача доводит игру до установленной', () async {
      final game = await downloadingGame();

      downloads.add(EngineTasksChanged([done(game.downloadTaskId!)]));
      final state = await waitForLibrary(
        (s) => s.gameById(game.id)?.status == GameStatus.installed,
      );

      expect(engine.calls, contains('verify task-1'));
      expect(state.gameById(game.id)!.downloadTaskId, isNull);
    });
  });

  group('порядок очереди', () {
    DownloadTask waiting(String id) =>
        DownloadTask(id: id, name: id, state: DownloadState.waiting);

    test('перестановка считает движку номер по соседу', () async {
      downloads.add(
        EngineTasksChanged([waiting('a'), waiting('b'), waiting('c')]),
      );
      await waitForDownloads((s) => s.tasks.length == 3);

      downloads.add(const DownloadReordered(id: 'c', beforeId: 'a'));
      await waitForCall('reorder c -> 0');
    });

    test('в конец очереди — это за последнего', () async {
      downloads.add(EngineTasksChanged([waiting('a'), waiting('b')]));
      await waitForDownloads((s) => s.tasks.length == 2);

      downloads.add(const DownloadReordered(id: 'a'));
      await waitForCall('reorder a -> 1');
    });

    // Сосед мог уехать из списка между нажатием и обработкой: движку в
    // таком случае поручать нечего — номера у перестановки нет.
    test('неизвестный сосед оставляет очередь как есть', () async {
      downloads.add(EngineTasksChanged([waiting('a')]));
      await waitForDownloads((s) => s.tasks.length == 1);

      downloads.add(const DownloadReordered(id: 'a', beforeId: 'нет такого'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(engine.calls, isEmpty);
    });
  });

  group('выгрузка файла раздачи', () {
    test('файл движка ложится туда, куда попросили', () async {
      final game = await downloadingGame();
      final enginePath = p.join(tmp.path, 'движок.torrent');
      await File(enginePath).writeAsString('d4:infod');
      engine.torrentPath = enginePath;
      final destination = p.join(tmp.path, 'вынесенное.torrent');

      downloads.add(
        TorrentExportRequested(game: game, destination: destination),
      );
      final state = await waitForDownloads((s) => s.notice != null);

      expect(state.notice!.isError, isFalse);
      expect(File(destination).existsSync(), isTrue);
    });

    test('нечего выгружать — так и говорят', () async {
      final game = await downloadingGame();
      final destination = p.join(tmp.path, 'вынесенное.torrent');

      downloads.add(
        TorrentExportRequested(game: game, destination: destination),
      );
      final state = await waitForDownloads((s) => s.notice != null);

      expect(state.notice!.isError, isTrue);
      expect(File(destination).existsSync(), isFalse);
    });
  });

  group('движок и настройки', () {
    test('запуск идёт после ограничений, а не до', () async {
      downloads.add(const DownloadEngineStartRequested());
      await waitForCall('start');

      expect(
        engine.calls.indexOf('applyLimits'),
        lessThan(engine.calls.indexOf('start')),
        reason: 'движок не должен успеть разогнаться мимо предела',
      );
    });

    test('перезапуск останавливает движок перед подъёмом', () async {
      downloads.add(const DownloadEngineRestartRequested());
      await waitForCall('start');

      expect(engine.calls, containsAllInOrder(['stop', 'start']));
    });

    // Про запущенную игру знает библиотека, про скорость — настройки;
    // свести их может только тот, кто владеет движком.
    test('запуск игры пересчитывает пределы скорости', () async {
      await downloads.applyLimits();
      expect(engine.appliedPlaying, isFalse);

      downloads.add(const DownloadLimitsRefreshed());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(engine.appliedLimits, settings.state.limits);
    });
  });

  // Прокси включают ради скрытности, и «не смогли — пошли напрямую» здесь
  // худший ответ. Служба перехвата теперь отказывает, а сказать об этом
  // человеку может только блок: у службы ни `Notice`, ни языка.
  group('об отвалившемся прокси человеку говорят', () {
    Future<void> useProxy() async {
      settings.add(
        SettingsPatched(
          (s) => s.copyWith(
            proxy: const ProxySettings(
              enabled: true,
              host: 'proxy.example',
              port: 1080,
            ),
          ),
        ),
      );
      await waitForState(settings, (s) => s.proxy.host == 'proxy.example');
    }

    test('отказ прокси приходит сообщением об ошибке', () async {
      await useProxy();

      proxyRouting.value = ProxyRouting.blocked;
      final state = await waitForState(downloads, (s) => s.notice != null);

      expect(state.notice!.isError, isTrue);
      expect(state.notice!.message, contains('proxy.example'));
    });

    // Иначе всякая смена настроек заканчивалась бы сообщением о прокси,
    // который работает.
    test('работающий прокси человека не беспокоит', () async {
      await useProxy();

      proxyRouting.value = ProxyRouting.through;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(downloads.state.notice, isNull);
    });
  });
}
