import 'dart:io';

import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/models/catalog_progress.dart';
import 'package:evaporate/services/saves/ludusavi_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

void main() {
  group('доля выполненного', () {
    test('считается от полученного и общего', () {
      const progress = CatalogProgress(
        phase: CatalogPhase.downloading,
        received: 5,
        total: 20,
      );

      expect(progress.fraction, 0.25);
    });

    // Сервер не обязан сообщать длину. Показывать выдуманное число хуже,
    // чем честно бегущую полосу.
    test('без известного размера доли нет', () {
      const progress = CatalogProgress(
        phase: CatalogPhase.downloading,
        received: 5,
      );

      expect(progress.fraction, isNull);
    });

    test('у разбора доли нет: он идёт одним куском в изоляте', () {
      expect(CatalogProgress.parsing.fraction, isNull);
    });

    test('доля не выходит за единицу', () {
      const progress = CatalogProgress(
        phase: CatalogPhase.downloading,
        received: 30,
        total: 20,
      );

      expect(progress.fraction, 1.0);
    });
  });

  group('каталог сообщает о ходе работы', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('evaporate_progress_');
    });

    tearDown(() async {
      try {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      } on FileSystemException {
        // Остатки временной папки на результат теста не влияют.
      }
    });

    test('разбор объявляется отдельным этапом', () async {
      final seen = <CatalogPhase>[];
      final catalog = LudusaviCatalog(
        cacheFile: p.join(tmp.path, 'paths.json'),
        fetch: (uri) async => 'Игра:\n  files:\n',
        onProgress: (value) => seen.add(value.phase),
      );

      await catalog.ensureLoaded();

      expect(
        seen,
        contains(CatalogPhase.parsing),
        reason: 'четыре секунды разбора без слов выглядят зависанием',
      );
    });
  });

  group('ход доходит до состояния', () {
    late Directory tmp;
    late AppPaths paths;
    late SettingsBloc settings;
    late LibraryBloc library;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('evaporate_progress_bloc_');
      paths = AppPaths.custom(
        dataDir: p.join(tmp.path, 'data'),
        defaultInstallDir: p.join(tmp.path, 'games'),
      );
      settings = SettingsBloc(paths);
      library = LibraryBloc(
        paths: paths,
        settings: settings,
        // Без подделок этот тест ушёл бы в сеть за настоящим манифестом на
        // семнадцать мегабайт и упирался в таймаут.
        savePaths: LudusaviCatalog(
          cacheFile: p.join(tmp.path, 'paths.json'),
          fetch: (uri) async => 'Игра:\n  files:\n',
        ),
      );
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

    Future<LibraryState> waitFor(bool Function(LibraryState) test) {
      if (test(library.state)) return Future.value(library.state);
      return library.stream
          .firstWhere(test)
          .timeout(const Duration(seconds: 10));
    }

    test('сообщение о ходе попадает в состояние', () async {
      library.add(
        const SavePathsProgressChanged(
          CatalogProgress(
            phase: CatalogPhase.downloading,
            received: 1,
            total: 4,
          ),
        ),
      );

      final state = await waitFor((s) => s.savePathsProgress != null);

      expect(state.savePathsProgress!.fraction, 0.25);
    });

    // Оставшись висеть, указатель врал бы о продолжающейся работе.
    test('по завершении поиска указатель гаснет', () async {
      final id = const Uuid().v4();
      library.add(GameAdded(id: id, title: 'Какая-то игра'));
      await waitFor((s) => s.gameById(id) != null);

      library.add(const SavePathsProgressChanged(CatalogProgress.parsing));
      await waitFor((s) => s.savePathsProgress != null);

      library.add(SavePathsLookupRequested(library.state.gameById(id)!));
      final state = await waitFor(
        (s) =>
            !s.isBusy(LibraryBloc.savePathsKey(id)) &&
            s.savePathsProgress == null,
      );

      expect(state.savePathsProgress, isNull);
    });
  });
}
