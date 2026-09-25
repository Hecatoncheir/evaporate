import 'dart:math' as math;

import 'package:evaporate/ui/ev/data/game_facts.dart';
import 'package:evaporate/ui/ev/data/sample_data.dart';
import 'package:evaporate/ui/ev/design/effects.dart';
import 'package:evaporate/ui/ev/design/tokens.dart';
import 'package:evaporate/ui/ev/ev_app.dart';
import 'package:evaporate/ui/ev/launch/ev_launch_ritual.dart';
import 'package:evaporate/ui/ev/sheet/ev_game_sheet.dart';
import 'package:evaporate/ui/ev/shell/ev_section.dart';
import 'package:evaporate/ui/ev/shell/ev_shell.dart';
import 'package:evaporate/ui/ev/widgets/ev_game_card.dart';
import 'package:evaporate/ui/ev/widgets/ev_play_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void _window(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Ядро «Играть» дышит бесконечно: вместо pumpAndSettle — секунда.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

Future<EvEffects> _app(WidgetTester tester, {EvEffects? effects}) async {
  final e = effects ?? EvEffects.still();
  addTearDown(e.dispose);
  await tester.pumpWidget(EvaporateApp(effects: e));
  await _settle(tester);
  return e;
}

Finder _inSheet(String text) => find.descendant(
  of: find.byType(EvGameSheet),
  matching: find.text(text, findRichText: true),
);

/// Открыть карточку игры из героя.
Future<void> _openFromHero(WidgetTester tester) async {
  await tester.tap(find.text('Подробнее'));
  await _settle(tester);
  expect(find.byType(EvGameSheet), findsOneWidget);
}

void main() {
  group('сведения об игре — числа прототипа', () {
    // Сняты в браузере из открытой карточки: те же поля, что считает
    // cardData, и в том же порядке обращений к генератору.
    test('«Пепельный Предел» — установленная игра', () {
      final f = EvGameFacts.of(sampleHero);
      expect(f.hours, 284);
      expect(f.lastMinutes, 90, reason: '1 ч 30 мин');
      // Давность — из библиотеки, как у героя, а не по сиду.
      expect(f.lastAgo, '6 минут назад');
      expect(f.unlocked, 3);
      expect(f.installed, isTrue);
      expect(f.parts.map((p) => formatGb(p.size)), [
        '54,0 ГБ',
        '8,2 ГБ',
        '6,2 ГБ',
        '7,9 ГБ',
        '2,4 ГБ',
      ]);
      expect(f.parts.first.required, isTrue);
      expect(formatGb(f.onDisk), '68,4 ГБ');
      expect(f.ratio, 1.25);
      expect(formatGb(f.uploaded), '85,5 ГБ');
      expect(f.peers, 8);
      expect(f.friends, hasLength(3));
      expect(f.sessions.where((m) => m > 0), hasLength(7));
    });

    test('«Неон Хальцион» — в очереди, ещё не запускали', () {
      final game = sampleLibrary.firstWhere((g) => g.title == 'Неон Хальцион');
      final f = EvGameFacts.of(game);
      expect(f.hours, 0);
      expect(f.unlocked, 0);
      expect(f.lastAgo, '—');
      expect(f.sessions, everyElement(0));
      expect(f.installed, isFalse);
      expect(f.parts.map((p) => formatGb(p.size)), [
        '19,0 ГБ',
        '2,9 ГБ',
        '2,2 ГБ',
        '2,8 ГБ',
        '0,8 ГБ',
      ]);
      expect(formatGb(f.toDownload), '27,7 ГБ');
      expect(f.ratio, 2.67);
      expect(formatGb(f.uploaded), '64,3 ГБ');
      expect(f.peers, 23);
    });
  });

  group('карточка в окне', () {
    testWidgets('«Подробнее» открывает её, Esc и крестик закрывают', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await _openFromHero(tester);

      expect(_inSheet('Пепельный Предел'), findsOneWidget);
      expect(_inSheet('В БИБЛИОТЕКЕ · СЫГРАНО 284 Ч'), findsOneWidget);
      expect(_inSheet('ВАША ИСТОРИЯ'), findsOneWidget);
      expect(_inSheet('Глава 5 · 62 %'), findsOneWidget);
      expect(_inSheet('68,4 ГБ на диске'), findsOneWidget);
      expect(_inSheet('85,5 ГБ'), findsOneWidget, reason: 'отдано');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);
      expect(find.byType(EvGameSheet), findsNothing);

      await _openFromHero(tester);
      await tester.tap(find.bySemanticsLabel('Закрыть'));
      await _settle(tester);
      expect(find.byType(EvGameSheet), findsNothing);
    });

    testWidgets('раскладка листа — размеры прототипа', (tester) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await _openFromHero(tester);

      // .sheet-in: min(1080, 100%) в поле clamp(12,3vw,40)
      final panel = tester.getRect(find.byType(CustomScrollView));
      expect(panel.width, 1080);
      expect(panel.height, 900 - 80);
      // .sheet-art: clamp(190px, 26vh, 280px)
      final art = tester.getRect(find.byType(EvGameSheet).first);
      expect(art.size, const Size(1440, 900), reason: 'лист во всё окно');
      final bar = tester.getRect(
        find.descendant(
          of: find.byType(SliverPersistentHeader),
          matching: find.byWidgetPredicate(
            (w) => w is SizedBox && w.height == 71,
          ),
        ),
      );
      expect(bar.height, 71, reason: 'полоса 12 + 46 + 12 и кромка');
      expect(bar.top - panel.top, 234, reason: 'обложка 26vh');
    });

    testWidgets('обложка не закрывает собой полосу действий', (tester) async {
      // Кадр вписан по «cover» и без обрезки вылезает на полосу: кнопка
      // «Играть» оказывалась под ним.
      _window(tester, 1440, 900);
      await _app(tester);
      await _openFromHero(tester);

      final play = find.descendant(
        of: find.byType(EvGameSheet),
        matching: find.byType(EvPlayButton),
      );
      final rect = tester.getRect(play);
      final image = await tester.runAsync(() async {
        final layer =
            tester.binding.rootElement!.renderObject!.debugLayer!
                as OffsetLayer;
        final picture = await layer.toImage(rect);
        final bytes = await picture.toByteData();
        picture.dispose();
        return bytes!;
      });
      var brightest = 0;
      for (var i = 0; i < image!.lengthInBytes; i += 4) {
        brightest = math.max(brightest, image.getUint8(i));
      }
      expect(brightest, greaterThan(200), reason: 'кнопка видна');
    });

    testWidgets('удержание в полосе закрывает карточку и запускает ритуал', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await _openFromHero(tester);

      final play = find.descendant(
        of: find.byType(EvGameSheet),
        matching: find.byType(EvPlayButton),
      );
      final gesture = await tester.startGesture(tester.getCenter(play));
      await tester.pump();
      await tester.pump(EvMotion.hold + const Duration(milliseconds: 40));
      await gesture.up();
      await _settle(tester);

      expect(
        find.byType(EvGameSheet, skipOffstage: false),
        findsNothing,
        reason: 'карточка ушла, а не спряталась за ритуалом',
      );
      expect(find.byType(EvLaunchRitual), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(EvLaunchRitual),
          matching: find.text('Пепельный Предел', findRichText: true),
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 320));
    });

    testWidgets('полка, «Продолжить» и палитра открывают ту же карточку', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _app(tester);

      // строка «Продолжить»
      await tester.tap(find.text('Глубина 9').first);
      await _settle(tester);
      expect(_inSheet('Глубина 9'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);

      // обложка на полке
      final card = find.byWidgetPredicate(
        (w) => w is EvGameCard && w.title == 'Лунная Колея',
      );
      await tester.ensureVisible(card);
      await _settle(tester);
      await tester.tap(card);
      await _settle(tester);
      expect(find.byType(EvGameSheet), findsOneWidget, reason: 'обложка');
      expect(_inSheet('Лунная Колея'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);

      // палитра: Enter открывает карточку, а не уводит на полку
      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await _settle(tester);
      await tester.enterText(find.byType(TextField), 'волчья');
      await _settle(tester);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _settle(tester);
      expect(_inSheet('Волчья Тропа'), findsOneWidget);
      expect(
        tester
            .widget<EvShell>(find.byType(EvShell, skipOffstage: false))
            .controller
            .section,
        EvSection.library,
      );
    });

    testWidgets('в очереди: своя полоса и пустая история', (tester) async {
      _window(tester, 1440, 900);
      await _app(tester);
      final card = find.byWidgetPredicate(
        (w) => w is EvGameCard && w.title == 'Неон Хальцион',
      );
      await tester.ensureVisible(card);
      await _settle(tester);
      await tester.tap(card);
      await _settle(tester);

      expect(_inSheet('В ОЧЕРЕДИ НА ЗАГРУЗКУ'), findsOneWidget);
      expect(_inSheet('Скачать сейчас'), findsOneWidget);
      expect(_inSheet('Убрать из очереди'), findsOneWidget);
      expect(_inSheet('в очереди · вторая'), findsOneWidget);
      expect(_inSheet('ЕЩЁ НЕ ЗАПУСКАЛИ'), findsOneWidget);
      expect(
        _inSheet('История появится после первого запуска'),
        findsOneWidget,
      );
      expect(_inSheet('Сохранений пока нет'), findsOneWidget);
      expect(_inSheet('27,7 ГБ к загрузке'), findsOneWidget);
      expect(_inSheet('Начать раздачу'), findsOneWidget);
    });

    testWidgets('состав: часть снимается, обязательная — нет', (tester) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await _openFromHero(tester);

      final list = find.byType(CustomScrollView);
      await tester.drag(list, const Offset(0, -700));
      await _settle(tester);

      expect(_inSheet('68,4 ГБ на диске'), findsOneWidget);

      // Полосы состава и достижений: доли во всю высоту и от левого края,
      // а не нулевые и не по центру.
      final stack = find.descendant(
        of: find.byType(EvGameSheet),
        matching: find.byWidgetPredicate((w) => w is SizedBox && w.height == 8),
      );
      final track = tester.getRect(stack);
      final fill = tester.getRect(
        find.descendant(of: stack, matching: find.byType(DecoratedBox)).first,
      );
      expect(fill.height, 8);
      expect(fill.left, track.left);

      final achievements = find.descendant(
        of: find.byType(EvGameSheet),
        matching: find.byWidgetPredicate((w) => w is SizedBox && w.height == 5),
      );
      final bar = tester.getRect(achievements);
      final lit = tester.getRect(
        find
            .descendant(
              of: find.descendant(
                of: achievements,
                matching: find.byType(FractionallySizedBox),
              ),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(lit.left, bar.left, reason: 'заливка идёт от левого края');
      expect(lit.width, closeTo(bar.width * 3 / 5, 1), reason: '3 из 5');

      await tester.tap(_inSheet('Русская озвучка'));
      await _settle(tester);
      expect(
        _inSheet('60,2 ГБ на диске'),
        findsOneWidget,
        reason: '68,4 − 8,2',
      );

      await tester.tap(_inSheet('Игра'));
      await _settle(tester);
      expect(
        _inSheet('60,2 ГБ на диске'),
        findsOneWidget,
        reason: 'обязательная часть не снимается',
      );
    });
  });
}
