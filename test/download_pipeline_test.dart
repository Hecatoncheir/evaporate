import 'dart:io';

import 'package:evaporate/bloc/downloads/downloads_bloc.dart';
import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/models/download_task.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/services/notifications/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'support/recording_notifications.dart';

/// Путь «докачалось — установлено»: то, что происходит между сообщением
/// движка о готовой задаче и игрой, которую можно запустить.
void main() {
  // Папка установки выводится из состава раздачи, и цена ошибки здесь не
  // косметическая: этот же путь потом удаляют вместе с игрой.
  group('папка установки по составу раздачи', () {
    DownloadTask task({String? dir, List<String> files = const []}) =>
        DownloadTask(
          id: 'task-1',
          name: 'раздача',
          state: DownloadState.complete,
          dir: dir,
          files: files,
        );

    test('раздача с общей папкой даёт именно её, а не каталог загрузок', () {
      final derived = DownloadsBloc.deriveInstallDir(
        task(
          dir: '/dl',
          files: ['/dl/Игра/game.exe', '/dl/Игра/data/pak01.dat'],
        ),
      );

      expect(derived, p.join('/dl', 'Игра'));
    });

    // Иначе «удалить игру» снесло бы соседние раздачи вместе с ней.
    test('файлы вразнобой оставляют каталог загрузок нетронутым', () {
      final derived = DownloadsBloc.deriveInstallDir(
        task(dir: '/dl', files: ['/dl/Игра/game.exe', '/dl/readme.txt']),
      );

      expect(derived, '/dl');
    });

    test('единственный файл в корне не выдумывает подпапку', () {
      final derived = DownloadsBloc.deriveInstallDir(
        task(dir: '/dl', files: ['/dl/game.exe']),
      );

      expect(derived, '/dl');
    });

    // Состав раздачи известен не всегда: пока идут метаданные magnet-ссылки,
    // списка файлов ещё нет.
    test('без списка файлов берётся папка задачи', () {
      expect(DownloadsBloc.deriveInstallDir(task(dir: '/dl')), '/dl');
    });

    test('без папки задачи выручает путь первого файла', () {
      final derived = DownloadsBloc.deriveInstallDir(
        task(files: ['/где-то/Игра/game.exe']),
      );

      // Разделители достаются от самого пути и на Windows не переписываются,
      // поэтому здесь строка, а не p.join.
      expect(derived, '/где-то/Игра');
    });

    test('ни папки, ни файлов — решать не по чему', () {
      expect(DownloadsBloc.deriveInstallDir(task()), isNull);
    });
  });

  group('завершение загрузки', () {
    late Directory tmp;
    late AppPaths paths;
    late SettingsBloc settings;
    late LibraryBloc library;
    late DownloadsBloc downloads;
    late RecordingNotificationService notifications;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('evaporate_pipeline_');
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
        // Выход из игры запускает обход папок в поисках следов её работы —
        // настоящие «Документы» тут обходить незачем.
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

    /// Игра, которую движок «качает»: статус и идентификатор задачи
    /// выставлены вручную, поэтому настоящий движок для теста не нужен.
    Future<Game> downloadingGame({String taskId = 'task-1'}) async {
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

    /// Что считается запускаемым, зависит от системы: на Windows это `.exe`,
    /// на macOS и Linux — скрипт или файл с битом запуска.
    final executableName = Platform.isWindows ? 'game.exe' : 'game.sh';

    /// Скачанная папка с чем-то запускаемым внутри.
    Future<String> downloadedDir(String name) async {
      final dir = Directory(p.join(tmp.path, 'загрузки', name));
      await dir.create(recursive: true);
      await File(p.join(dir.path, executableName)).writeAsString('#!/bin/sh');
      return dir.path;
    }

    /// Уведомление уходит уже после того, как игра стала установленной:
    /// между этим лежит запись библиотеки на диск. Поэтому ждём его само,
    /// а не считаем, что оно успело.
    Future<List<AppNotification>> waitForNotifications(
      NotificationKind kind,
    ) async {
      for (var i = 0; i < 100; i++) {
        final sent = notifications.ofKind(kind);
        if (sent.isNotEmpty) return sent;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      return notifications.ofKind(kind);
    }

    DownloadTask completed(String taskId, String dir) => DownloadTask(
      id: taskId,
      name: 'Игра [RePack]',
      state: DownloadState.complete,
      dir: p.dirname(dir),
      files: [p.join(dir, executableName)],
      totalBytes: 2,
      completedBytes: 2,
    );

    test('готовая задача переводит игру в установленную', () async {
      final game = await downloadingGame();
      final dir = await downloadedDir('Игра');

      downloads.add(EngineTasksChanged([completed(game.downloadTaskId!, dir)]));
      final state = await waitForLibrary(
        (s) => s.gameById(game.id)?.status == GameStatus.installed,
      );

      final installed = state.gameById(game.id)!;
      expect(installed.installDir, dir);
      // Задача отжила своё: держать её идентификатор дальше незачем.
      expect(installed.downloadTaskId, isNull);
      expect(installed.sizeBytes, 2);
    });

    test('исполняемый файл в скачанной папке находится сам', () async {
      final game = await downloadingGame();
      final dir = await downloadedDir('Игра');

      downloads.add(EngineTasksChanged([completed(game.downloadTaskId!, dir)]));
      final state = await waitForLibrary(
        (s) => s.gameById(game.id)?.executablePath != null,
      );

      expect(
        state.gameById(game.id)!.executablePath,
        p.join(dir, executableName),
      );
    });

    // Об успехе уведомляют по той же причине, что и о провале: к концу
    // загрузки окно обычно свёрнуто, и SnackBar в нём никто не увидит.
    test('о завершённой загрузке приходит системное уведомление', () async {
      final game = await downloadingGame();
      final dir = await downloadedDir('Игра');

      downloads.add(EngineTasksChanged([completed(game.downloadTaskId!, dir)]));
      await waitForLibrary(
        (s) => s.gameById(game.id)?.status == GameStatus.installed,
      );

      final sent = await waitForNotifications(
        NotificationKind.downloadFinished,
      );
      expect(sent, hasLength(1));
      expect(sent.single.body, contains('Игра'));
    });

    // Опрос движка идёт раз в секунду, и та же готовая задача приходит
    // снова и снова: установка не должна выполняться на каждый опрос.
    test(
      'повторный доклад о той же задаче не переустанавливает игру',
      () async {
        final game = await downloadingGame();
        final dir = await downloadedDir('Игра');
        final task = completed(game.downloadTaskId!, dir);

        downloads.add(EngineTasksChanged([task]));
        await waitForLibrary(
          (s) => s.gameById(game.id)?.status == GameStatus.installed,
        );
        // Первого уведомления именно дожидаемся: иначе «пришло ровно одно»
        // подтвердилось бы и в случае, когда не пришло ни одного.
        await waitForNotifications(NotificationKind.downloadFinished);

        downloads.add(EngineTasksChanged([task]));
        downloads.add(EngineTasksChanged([task]));
        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(
          notifications.ofKind(NotificationKind.downloadFinished),
          hasLength(1),
        );
      },
    );
  });
}
