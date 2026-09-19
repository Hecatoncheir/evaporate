import 'dart:io';

import 'package:evaporate/core/format.dart';
import 'package:evaporate/l10n/app_localizations.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/models/game_rating.dart';
import 'package:evaporate/ui/library/detail/rating_row.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// Оценка игры: подпись Steam, доля положительных, оба счётчика обзоров и
/// оценка прессы.
void main() {
  const rating = GameRating(
    score: 9,
    summary: 'Крайне положительные',
    positive: 54551,
    negative: 2374,
    metacritic: 86,
  );

  group('строка оценки', () {
    Future<void> show(
      WidgetTester tester,
      GameRating value, {
      ThemeData? theme,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: theme ?? EvaporateTheme.dark(),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        locale: const Locale('ru'),
        home: Scaffold(
          body: Center(child: RatingRow(rating: value)),
        ),
      ),
    );

    testWidgets('подпись, доля и оба счётчика стоят рядом', (tester) async {
      await show(tester, rating);

      expect(find.text('Крайне положительные'), findsOneWidget);
      expect(find.text('96%'), findsOneWidget);
      // Разряды разделены неразрывным пробелом: сплошной ряд цифр
      // приходится пересчитывать глазом.
      expect(find.text('54 551'), findsOneWidget);
      expect(find.text('2 374'), findsOneWidget);
    });

    testWidgets('оценка прессы показывается только когда она есть', (
      tester,
    ) async {
      await show(tester, rating);
      expect(find.text('Metacritic 86'), findsOneWidget);

      await show(tester, const GameRating(summary: 'Смешанные', positive: 1));
      expect(find.textContaining('Metacritic'), findsNothing);
    });

    // «Палец вверх, пятьдесят четыре тысячи» в смысл не складывается,
    // поэтому диктору уходит цельная фраза, а значок с числом из
    // объявления убраны.
    testWidgets('счётчик объявляется диктору фразой, а не значком', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await show(tester, rating);

      expect(
        find.bySemanticsLabel('54 551 положительных обзоров'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('2 374 отрицательных обзоров'),
        findsOneWidget,
      );
      handle.dispose();
    });

    // Цвет берётся от ступени Steam, а не от доли: у Steam граница между
    // «смешанными» и «в основном положительными» зависит ещё и от числа
    // обзоров, и своя граница по проценту красила бы вопреки подписи.
    testWidgets('смешанные обзоры не красятся как положительные', (
      tester,
    ) async {
      final theme = EvaporateTheme.dark();
      final colors = theme.extension<EvaporatePalette>()!;

      await show(
        tester,
        const GameRating(
          score: 5,
          summary: 'Смешанные',
          positive: 70,
          negative: 30,
        ),
        theme: theme,
      );

      final text = tester.widget<Text>(find.text('Смешанные'));
      expect(text.style!.color, colors.warning);
    });
  });

  group('на странице игры', () {
    late Directory tmp;

    // Папка готовится снаружи: настоящий файловый ввод-вывод внутри
    // `testWidgets` не завершается никогда.
    setUp(() async => tmp = await TestHarness.makeTempDir());
    tearDown(() => TestHarness.removeTempDir(tmp));

    Future<TestHarness> openGame(
      WidgetTester tester, {
      GameRating? value,
    }) async {
      final harness = TestHarness(tmp);
      addTearDown(harness.dispose);

      final id = harness.addGame(
        title: 'Тестовая игра',
        installDir: '/tmp/game',
        status: GameStatus.installed,
      );
      await harness.pump(tester);
      if (value != null) {
        harness.seedGame(
          harness.library.state.gameById(id)!.copyWith(rating: value),
        );
        // Правку библиотеки блок кладёт на диск через 400 мс после события,
        // и это время тесту надо отмотать: иначе таймер переживёт дерево
        // виджетов и уронит прогон на проверке невыполненных таймеров.
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Тестовая игра').first);
      await tester.pumpAndSettle();
      return harness;
    }

    testWidgets('оценка видна в шапке', (tester) async {
      await openGame(tester, value: rating);

      expect(find.byType(RatingRow), findsOneWidget);
      expect(find.text('Крайне положительные'), findsOneWidget);
      expect(find.text('Metacritic 86'), findsOneWidget);
    });

    // Игра без единого обзора и без оценки прессы оценки не имеет вовсе, и
    // пустая строка на её месте была бы строкой ни о чём.
    testWidgets('игре без оценки строки не отводится', (tester) async {
      await openGame(tester);

      expect(find.byType(RatingRow), findsNothing);
    });
  });

  group('устройство оценки', () {
    test('доля считается от обоих счётчиков', () {
      expect(rating.total, 56925);
      expect(rating.positiveShare, 96);
    });

    test('разряды разделяются неразрывным пробелом', () {
      expect(formatCount(7), '7');
      expect(formatCount(999), '999');
      expect(formatCount(1000), '1 000');
      expect(formatCount(54551), '54 551');
      expect(formatCount(1234567), '1 234 567');
    });

    test('оценка прессы без обзоров — всё ещё оценка', () {
      expect(const GameRating(metacritic: 86).hasAnything, isTrue);
      expect(const GameRating(positive: 1).hasAnything, isTrue);
      expect(const GameRating().hasAnything, isFalse);
    });

    test('оценка переживает запись и чтение', () {
      final restored = Game.fromJson(
        Game(
          id: 'g1',
          title: 'Игра',
          addedAt: DateTime.now(),
          rating: rating,
        ).toJson(),
      );

      expect(restored.rating, rating);
    });

    // Библиотеки, записанные до появления оценки, лежат у людей на дисках.
    test('запись без оценки читается без неё же', () {
      final restored = Game.fromJson(
        Game(id: 'g1', title: 'Игра', addedAt: DateTime.now()).toJson(),
      );

      expect(restored.rating, isNull);
    });
  });
}
