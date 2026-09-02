import 'dart:io';

import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/models/save_profile.dart';
import 'package:evaporate/models/save_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

void main() {
  late Directory tmp;
  late AppPaths paths;
  late SettingsBloc settings;
  late LibraryBloc library;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_conflict_');
    paths = AppPaths.custom(
      dataDir: p.join(tmp.path, 'data'),
      defaultInstallDir: p.join(tmp.path, 'games'),
    );
    settings = SettingsBloc(paths);
    library = LibraryBloc(paths: paths, settings: settings);
  });

  tearDown(() async {
    await library.persist();
    await library.close();
    await settings.close();
    try {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    } on FileSystemException {
      // Остатки временной папки на результат теста не влияют.
    }
  });

  Future<LibraryState> waitFor(bool Function(LibraryState) condition) {
    if (condition(library.state)) return Future.value(library.state);
    return library.stream
        .firstWhere(condition)
        .timeout(const Duration(seconds: 10));
  }

  Future<LibraryState> waitForNotice(String fragment) {
    return waitFor(
      (s) =>
          !s.isBusy(LibraryBloc.bulkKey) &&
          (s.notice?.message.contains(fragment) ?? false),
    );
  }

  Future<({String id, File save})> gameWithSave(String title) async {
    final id = const Uuid().v4();
    final dir = Directory(p.join(tmp.path, 'saves', title));
    await dir.create(recursive: true);
    final save = File(p.join(dir.path, 'slot.sav'));
    await save.writeAsString('исходный прогресс');

    library.add(GameAdded(id: id, title: title));
    final added = await waitFor((s) => s.gameById(id) != null);
    library.add(
      GameUpdated(
        added
            .gameById(id)!
            .copyWith(
              saveProfile: SaveProfile(
                rules: [
                  SavePathRule(
                    id: const Uuid().v4(),
                    label: 'Сохранения',
                    template: dir.path,
                  ),
                ],
              ),
            ),
      ),
    );
    await waitFor((s) => s.gameById(id)!.saveProfile.isConfigured);
    return (id: id, save: save);
  }

  Future<Directory> emptyDir(String name) async {
    final dir = Directory(p.join(tmp.path, name));
    await dir.create(recursive: true);
    return dir;
  }

  /// Делает здешние сохранения заведомо свежее пакета.
  Future<void> touchSave(File save, String content) async {
    await save.writeAsString(content);
    await save.setLastModified(DateTime.now().add(const Duration(hours: 2)));
  }

  test('время последнего изменения читается по файлам игры', () async {
    final game = await gameWithSave('Хронометр');
    final when = DateTime.now().subtract(const Duration(days: 3));
    await game.save.setLastModified(when);

    final changed = await library.saveManager.lastLocalChange(
      library.state.gameById(game.id)!,
    );

    expect(changed, isNotNull);
    expect(changed!.difference(when).inSeconds.abs(), lessThan(2));
  });

  test('у игры без файлов затирать нечего', () async {
    final id = const Uuid().v4();
    library.add(GameAdded(id: id, title: 'Пустая'));
    await waitFor((s) => s.gameById(id) != null);

    final changed = await library.saveManager.lastLocalChange(
      library.state.gameById(id)!,
    );

    expect(changed, isNull);
  });

  // Ради этого всё и затевалось: пакет с другого устройства может оказаться
  // старым, и восстановить его — значит откатить чужой прогресс.
  test('свежий прогресс не затирается старым пакетом', () async {
    final game = await gameWithSave('Заезженная');
    final folder = await emptyDir('обмен');

    library.add(BulkExportRequested(folder.path));
    await waitForNotice('Выгружено');

    await touchSave(game.save, 'новый прогресс');

    library.add(BulkImportRequested(folder.path));
    final state = await waitForNotice('здесь новее');

    expect(state.notice!.message, contains('здесь новее, пропущено: 1'));
    expect(state.notice!.message, contains('применено: 0'));
    expect(
      await game.save.readAsString(),
      'новый прогресс',
      reason: 'файл обязан остаться нетронутым',
    );
  });

  test('явное разрешение перекрывает защиту', () async {
    final game = await gameWithSave('Перезаписываемая');
    final folder = await emptyDir('обмен2');

    library.add(BulkExportRequested(folder.path));
    await waitForNotice('Выгружено');

    await touchSave(game.save, 'новый прогресс');

    library.add(BulkImportRequested(folder.path, overwriteNewer: true));
    final state = await waitForNotice('применено: 1');

    expect(state.notice!.message, isNot(contains('здесь новее')));
    expect(await game.save.readAsString(), 'исходный прогресс');
  });

  test('старое на этом устройстве спокойно перезаписывается', () async {
    final game = await gameWithSave('Отставшая');
    final folder = await emptyDir('обмен3');

    library.add(BulkExportRequested(folder.path));
    await waitForNotice('Выгружено');

    // Правим файл, но отмечаем его прошлым: пакет свежее.
    await game.save.writeAsString('устаревший прогресс');
    await game.save.setLastModified(
      DateTime.now().subtract(const Duration(days: 5)),
    );

    library.add(BulkImportRequested(folder.path));
    final state = await waitForNotice('применено: 1');

    expect(state.notice!.message, isNot(contains('здесь новее')));
    expect(await game.save.readAsString(), 'исходный прогресс');
  });

  // Часы разных устройств расходятся, и без допуска конфликт срабатывал бы
  // на ровном месте — сразу после собственной выгрузки.
  test('разница в пределах допуска конфликтом не считается', () async {
    final game = await gameWithSave('Почти одновременная');
    final folder = await emptyDir('обмен4');

    library.add(BulkExportRequested(folder.path));
    await waitForNotice('Выгружено');

    await game.save.writeAsString('чуть позже');
    await game.save.setLastModified(
      DateTime.now().add(LibraryBloc.conflictTolerance ~/ 2),
    );

    library.add(BulkImportRequested(folder.path));
    final state = await waitForNotice('применено: 1');

    expect(state.notice!.message, isNot(contains('здесь новее')));
  });

  test('пакет для игры без сохранений применяется без вопросов', () async {
    final source = await gameWithSave('Донор');
    final folder = await emptyDir('обмен5');

    library.add(BulkExportRequested(folder.path));
    await waitForNotice('Выгружено');

    // Убираем файлы: затирать нечего, значит и конфликта нет.
    await source.save.delete();

    library.add(BulkImportRequested(folder.path));
    final state = await waitForNotice('применено: 1');

    expect(state.notice!.message, isNot(contains('здесь новее')));
    expect(await File(source.save.path).exists(), isTrue);
  });

  test('снимок сохранения помнит время создания', () async {
    final game = await gameWithSave('Со снимком');

    library.add(SnapshotRequested(library.state.gameById(game.id)!));
    final state = await waitFor(
      (s) => (s.snapshots[game.id]?.isNotEmpty ?? false),
    );

    final snapshot = state.snapshots[game.id]!.first;
    expect(
      DateTime.now().difference(snapshot.createdAt).inMinutes,
      lessThan(2),
      reason: 'по этому времени и сравниваются устройства',
    );
    expect(snapshot.createdAt, isA<DateTime>());
  });

  test('доступ к пакету не портит имя игры', () async {
    await gameWithSave('Игра С Пробелами');
    final folder = await emptyDir('обмен6');

    library.add(BulkExportRequested(folder.path));
    await waitForNotice('Выгружено');

    final packages = folder
        .listSync()
        .where((e) => e.path.endsWith(SaveSnapshot.fileExtension))
        .toList();
    expect(packages, hasLength(1));
    expect(p.basename(packages.single.path), contains('Игра С Пробелами'));
  });
}
