import 'dart:io';

import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/saves/saves_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/core/format.dart';
import 'package:evaporate/l10n/app_localizations.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/models/save_profile.dart';
import 'package:evaporate/models/save_snapshot.dart';
import 'package:evaporate/ui/library/saves/restore_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/temp_dir.dart';

/// Диалог восстановления — последнее, что человек видит перед перезаписью
/// своих сохранений. Всё, что он обещает, обязано совпадать с тем, что
/// сделает раскладка.
void main() {
  late Directory tmp;

  // Папка готовится снаружи: настоящий файловый I/O внутри testWidgets не
  // завершается.
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_restore_');
  });

  tearDown(() async {
    await deleteTempDir(tmp);
  });

  SaveSnapshot snapshotWith(String template) => SaveSnapshot(
    id: 's1',
    gameId: 'g1',
    gameTitle: 'Игра',
    createdAt: DateTime.now(),
    deviceName: 'другая машина',
    platform: currentPlatformKey(),
    sizeBytes: 10,
    archivePath: '',
    rules: [
      SavePathRule(
        id: 'снимок',
        label: SavePathRule.defaultLabel,
        template: template,
      ),
    ],
    fileCount: 1,
  );

  Future<void> show(
    WidgetTester tester, {
    required Game game,
    required SaveSnapshot snapshot,
  }) async {
    final paths = AppPaths.custom(
      dataDir: p.join(tmp.path, 'data'),
      defaultInstallDir: p.join(tmp.path, 'games'),
    );
    final settings = SettingsBloc(paths);
    final library = LibraryBloc(
      automaticMetadata: false,
      paths: paths,
      settings: settings,
    );
    final saves = SavesBloc(
      paths: paths,
      library: library,
      settings: settings,
      saveRoots: () => const [],
    );
    addTearDown(() async {
      await saves.close();
      await library.close();
      await settings.close();
    });

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: settings),
          BlocProvider.value(value: library),
          BlocProvider.value(value: saves),
        ],
        child: MaterialApp(
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          locale: const Locale('ru'),
          home: RestoreDialog(snapshot: snapshot, game: game),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Диалог подставлял сюда правило из снимка и показывал путь с чужой
  // машины — тот, куда здесь не запишут никогда, — да ещё и оставлял
  // клавишу доступной. Нажатие кончалось отказом «некуда класть».
  testWidgets('без своего правила цели не показывают и нажать не дают', (
    tester,
  ) async {
    final foreign = p.join(tmp.path, 'путь-с-чужой-машины');
    await show(
      tester,
      game: Game(id: 'g1', title: 'Игра', addedAt: DateTime.now()),
      snapshot: snapshotWith(foreign),
    );

    expect(find.textContaining(foreign), findsNothing);
    expect(find.textContaining('Не удалось'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
      reason: 'класть некуда — и предлагать нечего',
    );
  });

  testWidgets('своё правило показывают тем же путём, каким его разложат', (
    tester,
  ) async {
    final local = p.join(tmp.path, 'здешние-сейвы');
    await show(
      tester,
      game: Game(
        id: 'g1',
        title: 'Игра',
        addedAt: DateTime.now(),
        saveProfile: SaveProfile(
          rules: [
            SavePathRule(
              id: 'местное',
              label: SavePathRule.defaultLabel,
              template: local,
            ),
          ],
        ),
      ),
      snapshot: snapshotWith(p.join(tmp.path, 'путь-с-чужой-машины')),
    );

    expect(find.textContaining(local), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
}
