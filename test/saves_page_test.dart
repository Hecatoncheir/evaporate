import 'dart:io';

import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/models/save_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/test_app.dart';

/// Общий экран сохранений: показания хранилища и список всех снимков.
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await TestHarness.makeTempDir();
  });

  tearDown(() => TestHarness.removeTempDir(tmp));

  /// Ждёт настоящего файлового ввода-вывода, не выходя из фейкового времени.
  ///
  /// Обработчик события живёт в фейковой зоне теста и двигается только
  /// `pump`, а работа с диском — в настоящей и только в `runAsync`. Поэтому
  /// их приходится чередовать: одно без другого встаёт насмерть.
  Future<void> waitUntil(
    WidgetTester tester,
    bool Function() done,
    String what,
  ) async {
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (!done()) {
      if (DateTime.now().isAfter(deadline)) fail('не дождались: $what');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  /// Прокручивает отложенную работу с диском, чередуя зоны.
  Future<void> drain(WidgetTester tester, {int cycles = 15}) async {
    for (var i = 0; i < cycles; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  /// Открывает раздел сохранений с одним снятым снимком.
  Future<(TestHarness, String)> openWithSnapshot(WidgetTester tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);

    // Снимок снимается с настоящих файлов, поэтому папку готовим заранее.
    final savesDir = Directory(p.join(tmp.path, 'saves'));
    await tester.runAsync(() async {
      await savesDir.create(recursive: true);
      await File(p.join(savesDir.path, 'slot.sav')).writeAsString('прогресс');
    });

    final id = harness.addGame(
      title: 'Тихая гавань',
      status: GameStatus.installed,
      installDir: p.join(tmp.path, 'games', 'quiet'),
    );
    await harness.pump(tester);

    final game = harness.library.state.gameById(id)!;
    harness.library.add(
      GameUpdated(
        game.copyWith(
          saveProfile: SaveProfile(
            rules: [
              SavePathRule(
                id: 'rule-1',
                label: SavePathRule.defaultLabel,
                template: savesDir.path,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    harness.library.add(SnapshotRequested(harness.library.state.gameById(id)!));
    await waitUntil(
      tester,
      () => harness.library.state.snapshotsFor(id).isNotEmpty,
      'снимок не снялся',
    );
    await tester.pumpAndSettle();

    harness.nav.add(const SectionSelected(2));
    await tester.pumpAndSettle();
    return (harness, id);
  }

  // Раньше те же числа были рассыпаны по углам карточек, и на главный
  // вопрос «всё ли у меня сохранено» экран не отвечал.
  testWidgets('показания считают снимки, а не только перечисляют их', (
    tester,
  ) async {
    final (harness, id) = await openWithSnapshot(tester);

    expect(harness.library.state.snapshotsFor(id), hasLength(1));
    expect(find.text('СНИМКОВ'), findsOneWidget);
    expect(find.text('ЗАНЯТО'), findsOneWidget);
    expect(find.text('Тихая гавань'), findsWidgets);
  });

  // Удаление необратимо, а список общий: снимки разных игр лежат подряд, и
  // промахнуться мышью тут легко.
  testWidgets('перед удалением снимка спрашивают, называя игру', (
    tester,
  ) async {
    final (harness, id) = await openWithSnapshot(tester);

    await tester.tap(find.byTooltip('Удалить').first);
    await tester.pumpAndSettle();

    expect(find.text('Удалить снимок?'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('Тихая гавань'),
      ),
      findsOneWidget,
      reason: 'одной даты в общем списке недостаточно',
    );

    await tester.tap(find.widgetWithText(TextButton, 'Отмена'));
    await tester.pumpAndSettle();

    expect(
      harness.library.state.snapshotsFor(id),
      hasLength(1),
      reason: 'отказ не должен ничего удалять',
    );
  });

  testWidgets('удалённый снимок уходит и из списка, и из показаний', (
    tester,
  ) async {
    final (harness, id) = await openWithSnapshot(tester);
    final snapshot = harness.library.state.snapshotsFor(id).single;

    harness.library.add(SnapshotDeleted(snapshot));
    await tester.pump();

    expect(harness.library.state.snapshotsFor(id), isEmpty);
    // Обработчик после этого ещё убирает файл снимка и чистит хранилище —
    // настоящий ввод-вывод, которого дожидается закрытие библиотеки.
    // Не дать ему закончиться значит повесить сам тест на выходе.
    await drain(tester);

    expect(find.byTooltip('Удалить'), findsNothing);
    expect(find.textContaining('Снимков пока нет'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('подтверждение в диалоге доводит удаление до конца', (
    tester,
  ) async {
    final (harness, id) = await openWithSnapshot(tester);

    await tester.tap(find.byTooltip('Удалить').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
    await tester.pump();
    await drain(tester);

    expect(harness.library.state.snapshotsFor(id), isEmpty);
    expect(find.byTooltip('Удалить'), findsNothing);
  });
}
