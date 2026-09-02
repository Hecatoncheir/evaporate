import 'dart:io';

import 'package:evaporate/bloc/downloads/downloads_bloc.dart';
import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/models/download_task.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/models/save_snapshot.dart';
import 'package:evaporate/services/notifications/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'support/recording_notifications.dart';

void main() {
  late Directory tmp;
  late AppPaths paths;
  late SettingsBloc settings;
  late LibraryBloc library;
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
      paths: paths,
      settings: settings,
      notifications: notifications,
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
    await library.close();
    await settings.close();
    try {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    } on FileSystemException {
      // Остатки временной папки на результат теста не влияют.
    }
  });

  Future<LibraryState> waitForLibrary(bool Function(LibraryState) condition) {
    if (condition(library.state)) return Future.value(library.state);
    return library.stream
        .firstWhere(condition)
        .timeout(const Duration(seconds: 5));
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  /// Игра, которую движок «качает»: статус и идентификатор задачи выставлены
  /// вручную, поэтому настоящий движок для теста не нужен.
  Future<Game> downloadingGame({String taskId = 'taskId-1'}) async {
    final id = const Uuid().v4();
    library.add(GameAdded(id: id, title: 'Игра'));
    final added = await waitForLibrary((s) => s.gameById(id) != null);

    library.add(
      GameUpdated(
        added
            .gameById(id)!
            .copyWith(status: GameStatus.downloading, downloadTaskId: taskId),
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

    downloads.add(EngineTasksChanged([failedTask(game.downloadTaskId!)]));
    await waitForLibrary(
      (s) => s.gameById(game.id)?.status == GameStatus.error,
    );

    final failures = notifications.ofKind(NotificationKind.downloadFailed);
    expect(failures, hasLength(1));
    expect(failures.single.body, contains('пиры не найдены'));
  });

  test('повторные опросы движка не плодят уведомлений', () async {
    final game = await downloadingGame();
    final task = failedTask(game.downloadTaskId!);

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
    downloads.add(EngineTasksChanged([failedTask(game.downloadTaskId!)]));
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
    library.add(
      SnapshotRequested(added.gameById(id)!, origin: SnapshotOrigin.autoOnExit),
    );
    await settle();

    final failures = notifications.ofKind(NotificationKind.saveFailed);
    expect(failures, hasLength(1));
    expect(failures.single.body, contains('Без путей'));
    // При этом всплывающего сообщения в интерфейсе быть не должно.
    expect(library.state.notice, isNull);
  });

  test('ручной снимок сообщает в интерфейсе, а не системой', () async {
    final id = const Uuid().v4();
    library.add(GameAdded(id: id, title: 'Ручная'));
    final added = await waitForLibrary((s) => s.gameById(id) != null);

    library.add(SnapshotRequested(added.gameById(id)!));
    await waitForLibrary((s) => s.notice != null);

    expect(library.state.notice?.isError, isTrue);
    expect(notifications.ofKind(NotificationKind.saveFailed), isEmpty);
  });
}
