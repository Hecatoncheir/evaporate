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
    tmp = await Directory.systemTemp.createTemp('evaporate_bulk_');
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

  /// Игра с настоящей папкой сохранений: массовые операции работают
  /// с файлами, поэтому подделывать их нечем.
  Future<String> gameWithSaves(String title, {bool withFiles = true}) async {
    final id = const Uuid().v4();
    final savesDir = Directory(p.join(tmp.path, 'saves', title));
    await savesDir.create(recursive: true);
    if (withFiles) {
      await File(p.join(savesDir.path, 'slot.sav'))
          .writeAsString('прогресс $title');
    }

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
                    template: savesDir.path,
                  ),
                ],
              ),
            ),
      ),
    );
    await waitFor((s) => s.gameById(id)!.saveProfile.isConfigured);
    return id;
  }

  Future<Directory> emptyDir(String name) async {
    final dir = Directory(p.join(tmp.path, name));
    await dir.create(recursive: true);
    return dir;
  }

  test('выгрузка складывает пакеты всех настроенных игр в папку', () async {
    await gameWithSaves('Первая');
    await gameWithSaves('Вторая');
    final target = await emptyDir('вывоз');

    library.add(BulkExportRequested(target.path));
    await waitFor((s) => s.notice != null && !s.isBusy(LibraryBloc.bulkKey));

    final packages = target
        .listSync()
        .where((e) => e.path.endsWith(SaveSnapshot.fileExtension))
        .toList();
    expect(packages, hasLength(2));
    expect(library.state.notice!.message, contains('Выгружено игр: 2'));
  });

  test('игра без заданных путей пропускается, а не ломает выгрузку', () async {
    await gameWithSaves('С путями');
    library.add(GameAdded(id: const Uuid().v4(), title: 'Без путей'));
    await waitFor((s) => s.games.length == 2);
    final target = await emptyDir('вывоз2');

    library.add(BulkExportRequested(target.path));
    await waitFor((s) => s.notice != null && !s.isBusy(LibraryBloc.bulkKey));

    expect(library.state.notice!.message, contains('пропущено: 1'));
  });

  test('игра с путями, но без файлов, считается пропущенной', () async {
    await gameWithSaves('Пустая', withFiles: false);
    final target = await emptyDir('вывоз3');

    library.add(BulkExportRequested(target.path));
    await waitFor((s) => s.notice != null && !s.isBusy(LibraryBloc.bulkKey));

    expect(library.state.notice!.message, contains('Выгружено игр: 0'));
    expect(library.state.notice!.isError, isFalse);
  });

  test('загрузка возвращает сохранения по названиям игр', () async {
    final id = await gameWithSaves('Возвращаемая');
    final target = await emptyDir('обмен');

    library.add(BulkExportRequested(target.path));
    await waitFor((s) => s.notice != null && !s.isBusy(LibraryBloc.bulkKey));

    // Портим сохранение, как будто это другое устройство.
    final rule = library.state.gameById(id)!.saveProfile.rules.first;
    final saveFile = File(p.join(rule.template, 'slot.sav'));
    await saveFile.writeAsString('чужой прогресс');

    library.add(BulkImportRequested(target.path));
    await waitFor(
      (s) =>
          !s.isBusy(LibraryBloc.bulkKey) &&
          (s.notice?.message.contains('применено') ?? false),
    );

    expect(await saveFile.readAsString(), 'прогресс Возвращаемая');
    expect(library.state.notice!.message, contains('применено: 1'));
  });

  test('пакет без подходящей игры отмечается, а не теряется молча', () async {
    await gameWithSaves('Своя игра');
    final target = await emptyDir('обмен2');

    library.add(BulkExportRequested(target.path));
    await waitFor((s) => s.notice != null && !s.isBusy(LibraryBloc.bulkKey));

    // Убираем игру: пакет остаётся без пары.
    final game = library.state.games.first;
    library.add(GameRemoved(game));
    await waitFor((s) => s.games.isEmpty);

    library.add(BulkImportRequested(target.path));
    await waitFor(
      (s) =>
          !s.isBusy(LibraryBloc.bulkKey) &&
          (s.notice?.message.contains('нет такой игры') ?? false),
    );

    expect(library.state.notice!.message, contains('нет такой игры: 1'));
    expect(library.state.notice!.isError, isTrue);
  });

  test('пустая папка не считается ошибкой', () async {
    final target = await emptyDir('пусто');

    library.add(BulkImportRequested(target.path));
    await waitFor((s) => s.notice != null && !s.isBusy(LibraryBloc.bulkKey));

    expect(library.state.notice!.message, contains('применено: 0'));
  });

  test('занятость снимается после массовой операции', () async {
    await gameWithSaves('Игра');
    final target = await emptyDir('вывоз4');

    library.add(BulkExportRequested(target.path));
    await waitFor((s) => s.notice != null);

    expect(library.state.isBusy(LibraryBloc.bulkKey), isFalse);
  });
}
