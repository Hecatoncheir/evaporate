import 'dart:io';

import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/models/bulk_report.dart';
import 'package:evaporate/models/save_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

void main() {
  group('модель отчёта', () {
    const report = BulkReport(
      isExport: false,
      entries: [
        BulkEntry(title: 'Одна', outcome: BulkOutcome.applied),
        BulkEntry(title: 'Две', outcome: BulkOutcome.skipped),
        BulkEntry(title: 'Три', outcome: BulkOutcome.failed, detail: 'диск'),
      ],
    );

    test('строки группируются по исходу', () {
      expect(report.withOutcome(BulkOutcome.applied), hasLength(1));
      expect(report.count(BulkOutcome.skipped), 1);
      expect(report.count(BulkOutcome.unmatched), 0);
    });

    // Пропущенное намеренно тревогой не считается: у игры просто нечего
    // переносить, и подсвечивать это как беду незачем.
    test('пропущенное намеренно не считается бедой', () {
      const calm = BulkReport(
        isExport: true,
        entries: [BulkEntry(title: 'Пустая', outcome: BulkOutcome.skipped)],
      );

      expect(calm.hasProblems, isFalse);
      expect(report.hasProblems, isTrue);
    });

    test('причина хранится рядом со строкой', () {
      expect(report.withOutcome(BulkOutcome.failed).single.detail, 'диск');
    });
  });

  group('отчёт после настоящей операции', () {
    late Directory tmp;
    late AppPaths paths;
    late SettingsBloc settings;
    late LibraryBloc library;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('evaporate_report_');
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

    Future<LibraryState> waitFor(bool Function(LibraryState) test) {
      if (test(library.state)) return Future.value(library.state);
      return library.stream
          .firstWhere(test)
          .timeout(const Duration(seconds: 10));
    }

    Future<void> addGame(String title, {bool withFiles = true}) async {
      final id = const Uuid().v4();
      final dir = Directory(p.join(tmp.path, 'saves', title));
      await dir.create(recursive: true);
      if (withFiles) {
        await File(p.join(dir.path, 'slot.sav')).writeAsString('прогресс');
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
                      template: dir.path,
                    ),
                  ],
                ),
              ),
        ),
      );
      await waitFor((s) => s.gameById(id)!.saveProfile.isConfigured);
    }

    test('выгрузка перечисляет игры поимённо', () async {
      await addGame('С файлами');
      await addGame('Без файлов', withFiles: false);
      library.add(GameAdded(id: const Uuid().v4(), title: 'Без путей'));
      await waitFor((s) => s.games.length == 3);

      final target = Directory(p.join(tmp.path, 'вывоз'));
      await target.create(recursive: true);
      library.add(BulkExportRequested(target.path));
      final state = await waitFor(
        (s) => s.bulkReport != null && !s.isBusy(LibraryBloc.bulkKey),
      );

      final report = state.bulkReport!;
      expect(report.isExport, isTrue);
      expect(report.withOutcome(BulkOutcome.applied).map((e) => e.title), [
        'С файлами',
      ]);
      expect(report.count(BulkOutcome.skipped), 2);
      // Про каждую пропущенную сказано, почему.
      expect(
        report.withOutcome(BulkOutcome.skipped).every((e) => e.detail != null),
        isTrue,
      );
    });

    test('загрузка называет пакеты без пары', () async {
      await addGame('Своя');
      final target = Directory(p.join(tmp.path, 'обмен'));
      await target.create(recursive: true);

      library.add(BulkExportRequested(target.path));
      await waitFor((s) => s.bulkReport?.isExport ?? false);

      library.add(GameRemoved(library.state.games.first));
      await waitFor((s) => s.games.isEmpty);

      library.add(BulkImportRequested(target.path));
      final state = await waitFor(
        (s) =>
            (s.bulkReport?.isExport == false) && !s.isBusy(LibraryBloc.bulkKey),
      );

      final unmatched = state.bulkReport!.withOutcome(BulkOutcome.unmatched);
      expect(unmatched.map((e) => e.title), ['Своя']);
      expect(unmatched.single.detail, isNotNull);
    });
  });
}
