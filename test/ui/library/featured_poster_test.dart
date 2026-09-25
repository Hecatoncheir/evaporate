import 'dart:io';

import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/ui/labels.dart';
import 'package:evaporate/ui/library/featured_game.dart';
import 'package:evaporate/ui/widgets/toned_chip.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

/// Надпись крупного кадра: метка, название, плашки и клавиши.
void main() {
  final l = LRu();

  late Directory tmp;

  setUp(() async => tmp = await TestHarness.makeTempDir());
  tearDown(() => TestHarness.removeTempDir(tmp));

  /// Библиотека из одной игры, поправленной [edit], в полном кадре.
  Future<void> show(WidgetTester tester, Game Function(Game) edit) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    harness.addGame(title: 'Тихая гавань', status: GameStatus.installed);
    await harness.pump(tester);
    harness.seedGame(edit(harness.library.state.games.single));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Finder inFrame(Finder finder) =>
      find.descendant(of: find.byType(FeaturedGame), matching: finder);

  // Наигранное время стояло в кадре отдельным показанием в углу, и в
  // полосе — ещё и в надстрочной метке. Теперь оно в плашке, и один раз.
  testWidgets('кадр называет статус, размер и наигранное — один раз', (
    tester,
  ) async {
    const playtime = Duration(hours: 3);
    await show(
      tester,
      (game) => game.copyWith(
        executablePath: 'game.exe',
        sizeBytes: 5 << 30,
        play: game.play.copyWith(playtime: playtime),
      ),
    );

    final duration = formatDurationLabel(l, playtime);
    expect(inFrame(find.text(l.statusInstalled)), findsOneWidget);
    expect(inFrame(find.text(bytesLabel(l, 5 << 30))), findsOneWidget);
    expect(inFrame(find.textContaining(duration)), findsOneWidget);
    expect(inFrame(find.text(l.featuredNoExecutable)), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // Погашенная клавиша без слова «почему» выглядит поломкой.
  testWidgets('без исполняемого файла кадр объясняет погашенную клавишу', (
    tester,
  ) async {
    await show(tester, (game) => game);

    expect(inFrame(find.text(l.featuredNoExecutable)), findsOneWidget);
    expect(inFrame(find.text(l.statusInstalled)), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('без источника кадр объясняет, почему скачать нельзя', (
    tester,
  ) async {
    await show(
      tester,
      (game) => game.copyWith(status: GameStatus.notInstalled),
    );

    expect(inFrame(find.text(l.featuredNoSource)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Второй ряд плашек вытолкнул бы клавиши из кадра высотой 238: не
  // влезшее срезается, а кадр не ломается.
  testWidgets('длинные плашки стоят одной строкой и не ломают кадр', (
    tester,
  ) async {
    await show(
      tester,
      (game) => game.copyWith(
        executablePath: 'game.exe',
        sizeBytes: 1 << 40,
        play: game.play.copyWith(playtime: const Duration(hours: 9999)),
      ),
    );
    // Узкое окно, но ещё с полным кадром: надпись сжата до наименьшей
    // ширины, и три плашки в неё не влезают.
    tester.view.physicalSize = const Size(900, 1000);
    await tester.pumpAndSettle();

    expect(
      tester.widget<FeaturedGame>(find.byType(FeaturedGame)).compact,
      isFalse,
    );
    expect(tester.takeException(), isNull);
    expect(inFrame(find.text(l.play)), findsOneWidget);
    final chips = inFrame(find.byType(TonedChip));
    expect(chips, findsNWidgets(3));
    expect(
      {for (var i = 0; i < 3; i++) tester.getRect(chips.at(i)).top},
      hasLength(1),
      reason: 'плашки ушли во второй ряд',
    );
  });
}
