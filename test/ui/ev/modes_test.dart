import 'package:evaporate/ui/ev/data/game_facts.dart';
import 'package:evaporate/ui/ev/data/sample_data.dart';
import 'package:evaporate/ui/ev/design/effects.dart';
import 'package:evaporate/ui/ev/ev_app.dart';
import 'package:evaporate/ui/ev/launch/ev_launch_ritual.dart';
import 'package:evaporate/ui/ev/modes/ev_pult.dart';
import 'package:evaporate/ui/ev/modes/ev_term.dart';
import 'package:evaporate/ui/ev/modes/ev_wall.dart';
import 'package:evaporate/ui/ev/modes/modes_data.dart';
import 'package:evaporate/ui/ev/screens/downloads_page.dart';
import 'package:evaporate/ui/ev/screens/term_page.dart';
import 'package:evaporate/ui/ev/screens/wall_page.dart';
import 'package:evaporate/ui/ev/sheet/ev_game_sheet.dart';
import 'package:evaporate/ui/ev/shell/ev_top_bar.dart';
import 'package:evaporate/ui/ev/util/units.dart';
import 'package:evaporate/ui/ev/widgets/ev_controls.dart';
import 'package:evaporate/ui/ev/widgets/ev_game_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void _window(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

Future<void> _app(WidgetTester tester) async {
  final effects = EvEffects.still();
  addTearDown(effects.dispose);
  await tester.pumpWidget(EvaporateApp(effects: effects, readCatalog: false));
  await _settle(tester);
}

Future<void> _view(WidgetTester tester, String label) async {
  await tester.tap(find.bySemanticsLabel(label));
  await _settle(tester);
}

/// Большая плитка «Стены» — чья она.
String _feature(WidgetTester tester) =>
    tester.widget<EvWallFeature>(find.byType(EvWallFeature)).game.title;

/// Строки «Терминала» сверху вниз.
List<String> _rows(WidgetTester tester) => [
  for (final line in tester.widgetList<EvTermLine>(find.byType(EvTermLine)))
    line.row.game.title,
];

String _selectedRow(WidgetTester tester) => tester
    .widgetList<EvTermLine>(find.byType(EvTermLine))
    .firstWhere((l) => l.selected)
    .row
    .game
    .title;

void main() {
  group('данные', () {
    test('давность одна: у недавних — из библиотеки, у остальных — старше', () {
      for (final g in sampleLibrary) {
        final f = EvGameFacts.of(g);
        if (g.lastPlayed != null) {
          expect(f.lastAgo, g.lastPlayed, reason: g.title);
        } else if (f.hours > 0) {
          expect(EvGameFacts.olderAgo, contains(f.lastAgo), reason: g.title);
        } else {
          expect(f.lastAgo, '—', reason: g.title);
        }
      }
    });

    test('фильтры «Стены»: недавние — герой и полка «Продолжить»', () {
      expect(EvWallFilter.all.of(sampleLibrary), hasLength(12));
      expect(EvWallFilter.ready.of(sampleLibrary), hasLength(8));
      expect(EvWallFilter.downloads.of(sampleLibrary), hasLength(4));
      expect(EvWallFilter.recent.of(sampleLibrary), [
        sampleHero,
        ...sampleSessions,
      ]);
    });

    test('сетка «Стены»: большая 3 × 2 первой, остальные мимо неё', () {
      final cells = evWallCells(width: 1304, count: 12, wide: true);
      final tile = cells[1];
      expect(tile.width, closeTo(153.4, .1), reason: 'восемь столбцов');
      expect(cells[0].width, closeTo(tile.width * 3 + 22, .01));
      expect(cells[0].height, closeTo(tile.height * 2 + 11, .01));
      expect(tile.left, closeTo(cells[0].right + 11, .01));
      for (var i = 0; i < cells.length; i++) {
        for (var k = i + 1; k < cells.length; k++) {
          expect(cells[i].overlaps(cells[k]), isFalse, reason: '$i и $k');
        }
      }
      // Уже 900 px окна большая — 2 × 2.
      final narrow = evWallCells(width: 700, count: 12, wide: false);
      expect(narrow[0].width, closeTo(narrow[1].width * 2 + 11, .01));
    });

    test('«Терминал»: от последней запущенной, нетронутые — в конце', () {
      final rows = evTermRows(sampleLibrary, EvTermSort.last, ascending: false);
      expect(rows.first.game, sampleHero);
      expect(rows.take(4).map((r) => r.game), [sampleHero, ...sampleSessions]);
      expect(rows.skip(8).every((r) => r.facts.hours == 0), isTrue);

      final hours = evTermRows(
        sampleLibrary,
        EvTermSort.hours,
        ascending: false,
      );
      expect(hours.first.game.title, 'Волчья Тропа');
      final names = evTermRows(sampleLibrary, EvTermSort.name, ascending: true);
      expect(names.first.game.title, 'Волчья Тропа');
      expect(names.last.game.title, 'Хальцион: Эхо');
    });

    test('главная кнопка: играть — если на диске, иначе в загрузки', () {
      final queued = sampleLibrary.firstWhere(
        (g) => g.state == EvGameState.queued,
      );
      expect(evMainAction(sampleHero), 'Играть');
      expect(evMainAction(queued), 'К загрузкам');
      expect(evPultAction(sampleHero), 'Продолжить');
      expect(evPultAction(queued), 'К загрузкам');
      expect(evPultLine(sampleHero), 'сыграно 284 ч · 68.4 ГБ');
    });
  });

  group('в окне', () {
    testWidgets('переключатель — только на библиотеке и не в узком окне', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _app(tester);
      expect(find.bySemanticsLabel('Стена'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await _settle(tester);
      expect(find.bySemanticsLabel('Стена'), findsNothing);

      // Уже 1080 px переключатель наезжал бы на поиск — его нет.
      for (final width in [700.0, 1040.0]) {
        _window(tester, width, 900);
        await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
        await _settle(tester);
        expect(find.bySemanticsLabel('Стена'), findsNothing);
        expect(tester.takeException(), isNull);
      }
      _window(tester, EvTopBar.toolsFrom, 900);
      await _settle(tester);
      expect(find.bySemanticsLabel('Стена'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'с порога — влезает');
    });

    testWidgets('«Стена»: выбор встаёт первым, фильтр считает, кнопка ведёт', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await _view(tester, 'Стена');
      expect(find.byType(WallPage), findsOneWidget);
      expect(find.text('12 из 12'), findsOneWidget);
      expect(_feature(tester), sampleHero.title);

      await tester.tap(find.bySemanticsLabel('Глубина 9'));
      await _settle(tester);
      expect(_feature(tester), 'Глубина 9');

      await tester.tap(find.text('Качаются'));
      await _settle(tester);
      expect(find.text('4 из 12'), findsOneWidget);
      expect(_feature(tester), 'Неон Хальцион');
      await tester.tap(find.text('К загрузкам'));
      await _settle(tester);
      expect(find.byType(DownloadsPage), findsOneWidget);
    });

    testWidgets('«Стена»: «Играть» — ритуал, «Подробнее» — карточка', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await _view(tester, 'Стена');
      await tester.tap(find.text('Подробнее'));
      await _settle(tester);
      expect(find.byType(EvGameSheet), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);
      await tester.tap(find.text('Играть'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(EvLaunchRitual), findsOneWidget);
    });

    testWidgets('«Терминал»: клик сортирует, повторный переворачивает', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await _view(tester, 'Терминал');
      expect(find.byType(TermPage), findsOneWidget);
      expect(
        find.textContaining('8 установлено', findRichText: true),
        findsOneWidget,
      );
      expect(_rows(tester).first, sampleHero.title);

      await _view(tester, 'Сортировать: Часы');
      expect(_rows(tester).first, 'Волчья Тропа');
      await _view(tester, 'Сортировать: Часы');
      expect(
        EvGameFacts.of(
          sampleLibrary.firstWhere((g) => g.title == _rows(tester).first),
        ).hours,
        0,
      );
      await _view(tester, 'Сортировать: Название');
      expect(_rows(tester).first, 'Волчья Тропа', reason: 'текст — с «А»');
    });

    testWidgets(
      '«Терминал»: ↓ ведёт строку, Enter запускает или ведёт в загрузки',
      (tester) async {
        _window(tester, 1440, 900);
        await _app(tester);
        await _view(tester, 'Терминал');
        expect(_selectedRow(tester), sampleHero.title);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(_selectedRow(tester), 'Глубина 9');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(
          _selectedRow(tester),
          sampleHero.title,
          reason: 'выше первой — некуда',
        );

        for (var i = 0; i < 20; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        }
        await tester.pump();
        expect(_selectedRow(tester), _rows(tester).last);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await _settle(tester);
        expect(find.byType(DownloadsPage), findsOneWidget);
      },
    );

    testWidgets('«Терминал»: Enter на игре с диска — ритуал', (tester) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await _view(tester, 'Терминал');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(EvLaunchRitual), findsOneWidget);
    });

    testWidgets('«Пульт»: P открывает, ← → листают по кругу, Esc выходит', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await _settle(tester);
      expect(find.byType(EvPult), findsOneWidget);
      expect(find.text('1 / 12'), findsOneWidget);
      expect(find.text('сыграно 284 ч · 68.4 ГБ'), findsOneWidget);
      // Приём — тот же, что в полосе окна.
      expect(
        find.descendant(
          of: find.byType(EvPult),
          matching: find.text(formatRate(1622, digits: 1)),
        ),
        findsOneWidget,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.text('2 / 12'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(find.text('12 / 12'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);
      expect(find.byType(EvPult), findsNothing);
    });

    testWidgets(
      '«Пульт»: Enter — ритуал, чужая — в загрузки, «Подробнее» — карточка',
      (tester) async {
        _window(tester, 1440, 900);
        await _app(tester);
        await _view(tester, 'Режим «Пульт», клавиша P');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(EvPult), findsNothing);
        expect(find.byType(EvLaunchRitual), findsOneWidget);
      },
    );

    testWidgets(
      '«Пульт»: игра не на диске ведёт в загрузки, клик по соседней листает',
      (tester) async {
        _window(tester, 1440, 900);
        await _app(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
        await _settle(tester);
        // Третья в каталоге стоит в очереди; до неё — две обложки справа.
        await tester.tap(find.bySemanticsLabel(sampleLibrary[2].title));
        await tester.pump();
        expect(find.text('3 / 12'), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byType(EvPult),
            matching: find.widgetWithText(EvGhostButton, 'Подробнее'),
          ),
        );
        await _settle(tester);
        expect(find.byType(EvPult), findsNothing);
        expect(find.byType(EvGameSheet), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await _settle(tester);

        await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
        await _settle(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        await tester.tap(find.text('К загрузкам'));
        await _settle(tester);
        expect(find.byType(DownloadsPage), findsOneWidget);
      },
    );

    testWidgets('«Разработка»: режимы переключают и возвращают в библиотеку', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _app(tester);
      Future<void> dev(String name) async {
        await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
        await _settle(tester);
        await tester.ensureVisible(find.text(name));
        await _settle(tester);
        await tester.tap(find.text(name));
        await _settle(tester);
      }

      await dev('D · Терминал');
      expect(find.byType(TermPage), findsOneWidget);
      await dev('B · Стена');
      expect(find.byType(WallPage), findsOneWidget);
      // Вид — выбор окна: уход в раздел его не сбрасывает.
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await _settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await _settle(tester);
      expect(find.byType(WallPage), findsOneWidget);
      await dev('C · Пульт');
      expect(find.byType(EvPult), findsOneWidget);
    });

    testWidgets('P в поле поиска печатается, а не открывает пульт', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
      await _settle(tester);
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await _settle(tester);
      expect(find.byType(EvPult), findsNothing);
    });
  });
}
