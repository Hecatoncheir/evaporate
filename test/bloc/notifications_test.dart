import 'dart:io';

import 'package:evaporate/bloc/downloads/downloads_bloc.dart';
import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/saves/saves_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/models/download_task.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/models/save_snapshot.dart';
import 'package:evaporate/services/notifications/notification_service.dart';
import 'package:evaporate/services/saves/save_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../support/recording_notifications.dart';
import '../support/temp_dir.dart';
import '../support/wait_for_state.dart';

void main() {
  late Directory tmp;
  late AppPaths paths;
  late SettingsBloc settings;
  late LibraryBloc library;
  late SavesBloc saves;
  late DownloadsBloc downloads;
  late RecordingNotificationService notifications;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_notify_');
    paths = AppPaths.custom(
      dataDir: p.join(tmp.path, 'data'),
      defaultInstallDir: p.join(tmp.path, 'games'),
    );
    notifications = RecordingNotificationService();
    settings = SettingsBloc(paths);
    library = LibraryBloc(
      automaticMetadata: false,
      paths: paths,
      settings: settings,
    );
    saves = SavesBloc(
      paths: paths,
      library: library,
      settings: settings,
      notifications: notifications,
      saveRoots: () => const [],
    );
    downloads = DownloadsBloc(
      paths: paths,
      library: library,
      settings: settings,
      notifications: notifications,
    );
  });

  tearDown(() async {
    await library.persist();
    await downloads.close();
    await saves.close();
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

  Future<SavesState> waitForSaves(bool Function(SavesState) condition) =>
      waitForState(saves, condition);

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  /// Игра, которую движок «качает»: статус и идентификатор задачи выставлены
  /// вручную, поэтому настоящий движок для теста не нужен.
  Future<Game> downloadingGame({String taskId = 'taskId-1'}) async {
    final id = const Uuid().v4();
    library.add(GameAdded(id: id, title: 'Игра'));
    await waitForLibrary((s) => s.gameById(id) != null);

    library.add(
      GameDownloadStarted(
        id,
        const GameSource(
          kind: GameSourceKind.magnet,
          value: 'magnet:?xt=urn:btih:test',
        ),
        taskId,
      ),
    );
    final ready = await waitForLibrary(
      (s) => s.gameById(id)?.status == GameStatus.downloading,
    );
    return ready.gameById(id)!;
  }

  DownloadTask failedTask(String taskId) => DownloadTask(
    id: taskId,
    name: 'раздача',
    state: DownloadState.error,
    errorMessage: 'пиры не найдены',
  );

  test('сорвавшаяся загрузка даёт системное уведомление', () async {
    final game = await downloadingGame();

    downloads.add(
      EngineTasksChanged([failedTask(game.download.downloadTaskId!)]),
    );
    await waitForLibrary(
      (s) => s.gameById(game.id)?.status == GameStatus.error,
    );

    final failures = notifications.ofKind(NotificationKind.downloadFailed);
    expect(failures, hasLength(1));
    expect(failures.single.body, contains('пиры не найдены'));
  });

  test('повторные опросы движка не плодят уведомлений', () async {
    final game = await downloadingGame();
    final task = failedTask(game.download.downloadTaskId!);

    // Движок опрашивается раз в секунду и присылает одно и то же состояние.
    downloads.add(EngineTasksChanged([task]));
    await waitForLibrary(
      (s) => s.gameById(game.id)?.status == GameStatus.error,
    );
    downloads.add(EngineTasksChanged([task]));
    downloads.add(EngineTasksChanged([task]));
    await settle();

    expect(
      notifications.ofKind(NotificationKind.downloadFailed),
      hasLength(1),
      reason: 'уведомляем только на переходе в ошибку',
    );
  });

  test('выключённая настройка отключает системные уведомления', () async {
    settings.add(
      SettingsChanged(settings.state.copyWith(systemNotifications: false)),
    );
    await settings.stream.firstWhere((s) => !s.systemNotifications);

    final game = await downloadingGame();
    downloads.add(
      EngineTasksChanged([failedTask(game.download.downloadTaskId!)]),
    );
    await waitForLibrary(
      (s) => s.gameById(game.id)?.status == GameStatus.error,
    );

    expect(notifications.sent, isEmpty);
  });

  test('провал автоснимка сохранений не остаётся незамеченным', () async {
    final id = const Uuid().v4();
    library.add(GameAdded(id: id, title: 'Без путей'));
    final added = await waitForLibrary((s) => s.gameById(id) != null);

    // Автоснимок молчит в интерфейсе — тем важнее системное уведомление.
    saves.add(
      SnapshotRequested(added.gameById(id)!, origin: SnapshotOrigin.autoOnExit),
    );
    await settle();

    final failures = notifications.ofKind(NotificationKind.saveFailed);
    expect(failures, hasLength(1));
    expect(failures.single.body, contains('Без путей'));
    // При этом всплывающего сообщения в интерфейсе быть не должно.
    expect(saves.state.notice, isNull);
  });

  test('ручной снимок сообщает в интерфейсе, а не системой', () async {
    final id = const Uuid().v4();
    library.add(GameAdded(id: id, title: 'Ручная'));
    final added = await waitForLibrary((s) => s.gameById(id) != null);

    saves.add(SnapshotRequested(added.gameById(id)!));
    await waitForSaves((s) => s.notice != null);

    expect(saves.state.notice?.isError, isTrue);
    expect(notifications.ofKind(NotificationKind.saveFailed), isEmpty);
  });

  // Файл сейва ещё держит игра, и снимок падает сырым
  // `FileSystemException`, а не `SaveException`. Эта ветка уведомления не
  // слала вовсе: тихий автоснимок проваливался тихо.
  test(
    'провал автоснимка по вводу-выводу тоже приходит уведомлением',
    () async {
      final failing = SavesBloc(
        paths: paths,
        library: library,
        settings: settings,
        notifications: notifications,
        saveManager: _BusyFileManager(paths),
        saveRoots: () => const [],
      );
      addTearDown(failing.close);
      final id = const Uuid().v4();
      library.add(GameAdded(id: id, title: 'Занятый файл'));
      final added = await waitForLibrary((s) => s.gameById(id) != null);

      failing.add(
        SnapshotRequested(
          added.gameById(id)!,
          origin: SnapshotOrigin.autoOnExit,
        ),
      );
      await settle();

      final failures = notifications.ofKind(NotificationKind.saveFailed);
      expect(failures, hasLength(1));
      expect(failures.single.body, contains('Занятый файл'));
    },
  );
}

/// Снимок падает так, как падает на Windows, пока игра держит сейв.
class _BusyFileManager extends SaveManager {
  _BusyFileManager(AppPaths paths) : super(paths: paths);

  @override
  Future<SaveSnapshot> createSnapshot(
    Game game, {
    SnapshotOrigin origin = SnapshotOrigin.manual,
    String? note,
  }) async => throw const FileSystemException('файл занят другим процессом');
}
