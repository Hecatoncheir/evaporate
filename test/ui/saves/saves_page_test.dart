import 'dart:io';

import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/bloc/saves/saves_bloc.dart';
import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/models/app_section.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/models/save_profile.dart';
import 'package:evaporate/ui/saves/saves_readout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/test_app.dart';

/// Общий экран сохранений: показания хранилища и список всех снимков.
void main() {
  // Ищем по ключу перевода, а не по строке: правка формулировки в
  // ARB иначе роняет тест, ничего не сломав в приложении.
  final l = LRu();

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
  ///
  /// Каждый шаг настоящего ввода-вывода требует своего цикла. Пятнадцати
  /// хватало, пока уборка хранилища удаляла файл одним вызовом; с корзиной
  /// у неё вынос, отметка времени и проход по корзине, и обработчик не
  /// успевал закончиться — тест вис на закрытии библиотеки.
  Future<void> drain(WidgetTester tester, {int cycles = 40}) async {
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

    harness.library.add(
      SaveRulesAdded(id, [
        SavePathRule(
          id: 'rule-1',
          label: SavePathRule.defaultLabel,
          template: savesDir.path,
        ),
      ]),
    );
    await tester.pump();

    harness.saves.add(SnapshotRequested(harness.library.state.gameById(id)!));
    await waitUntil(
      tester,
      () => harness.saves.state.snapshotsFor(id).isNotEmpty,
      'снимок не снялся',
    );
    await tester.pumpAndSettle();

    harness.nav.add(const SectionSelected(AppSection.saves));
    await tester.pumpAndSettle();
    return (harness, id);
  }

  // Раньше те же числа были рассыпаны по углам карточек, и на главный
  // вопрос «всё ли у меня сохранено» экран не отвечал.
  testWidgets('показания считают снимки, а не только перечисляют их', (
    tester,
  ) async {
    final (harness, id) = await openWithSnapshot(tester);

    expect(harness.saves.state.snapshotsFor(id), hasLength(1));
    expect(find.text('СНИМКОВ'), findsOneWidget);
    expect(find.text('ЗАНЯТО'), findsOneWidget);
    expect(find.text('Тихая гавань'), findsWidgets);
  });

  // Экран выбирает из состояний только игры и снимки. Остальное —
  // занятость, сообщения, запущенные игры — меняется часто, и прежде
  // каждая такая перемена пересобирала экран и заново сортировала все
  // снимки библиотеки.
  testWidgets('перемена, не касающаяся игр и снимков, экран не пересобирает', (
    tester,
  ) async {
    final (harness, id) = await openWithSnapshot(tester);
    final before = tester.widget<SavesReadout>(find.byType(SavesReadout));

    harness.library.add(RunningGamesChanged({id}));
    // Первый кадр доставляет событие, перестройка — на следующем: одного
    // `pump` мало, и тест проходил бы при любой подписке.
    await tester.pumpAndSettle();

    expect(harness.library.state.runningIds, {id});
    expect(
      identical(tester.widget<SavesReadout>(find.byType(SavesReadout)), before),
      isTrue,
    );
  });

  // Удаление необратимо, а список общий: снимки разных игр лежат подряд, и
  // промахнуться мышью тут легко.
  testWidgets('перед удалением снимка спрашивают, называя игру', (
    tester,
  ) async {
    final (harness, id) = await openWithSnapshot(tester);

    await tester.tap(find.byTooltip('Удалить').first);
    await tester.pumpAndSettle();

    expect(find.text(l.deleteSnapshotQuestion), findsOneWidget);
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
      harness.saves.state.snapshotsFor(id),
      hasLength(1),
      reason: 'отказ не должен ничего удалять',
    );
  });

  testWidgets('удалённый снимок уходит и из списка, и из показаний', (
    tester,
  ) async {
    final (harness, id) = await openWithSnapshot(tester);
    final snapshot = harness.saves.state.snapshotsFor(id).single;

    harness.saves.add(SnapshotDeleted(snapshot));
    await tester.pump();

    expect(harness.saves.state.snapshotsFor(id), isEmpty);
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

    expect(harness.saves.state.snapshotsFor(id), isEmpty);
    expect(find.byTooltip('Удалить'), findsNothing);
  });
}
