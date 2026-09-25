import 'dart:math' as math;

import 'package:evaporate/ui/ev/atmosphere/ember_field.dart';
import 'package:evaporate/ui/ev/atmosphere/ev_atmosphere.dart';
import 'package:evaporate/ui/ev/data/sample_data.dart';
import 'package:evaporate/ui/ev/design/effects.dart';
import 'package:evaporate/ui/ev/design/theme.dart';
import 'package:evaporate/ui/ev/design/tokens.dart';
import 'package:evaporate/ui/ev/ev_app.dart';
import 'package:evaporate/ui/ev/launch/ev_launch_ritual.dart';
import 'package:evaporate/ui/ev/launch/ritual_core.dart';
import 'package:evaporate/ui/ev/launch/ritual_timeline.dart';
import 'package:evaporate/ui/ev/library/hero_cta.dart';
import 'package:evaporate/ui/ev/shell/ev_palette.dart';
import 'package:evaporate/ui/ev/shell/ev_section.dart';
import 'package:evaporate/ui/ev/shell/ev_shell.dart';
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

/// Удержать «Играть» до конца заряда. Ритуал строится в том же кадре,
/// а его часы идут со следующего: после этого `pump()` — время ноль.
Future<void> _holdPlay(WidgetTester tester) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(EvPlayButton)),
  );
  // первый кадр после forward() только заводит тикер
  await tester.pump();
  await tester.pump(EvMotion.hold + const Duration(milliseconds: 40));
  await gesture.up();
  expect(find.byType(EvLaunchRitual), findsOneWidget, reason: 'ритуал пошёл');
  await tester.pump();
}

/// Досчитать ритуал до конца: он сам, кадр, в котором затемнение
/// начинает уходить, и уход.
Future<void> _finishRitual(WidgetTester tester) async {
  await tester.pump(EvRitualTiming.full);
  await tester.pump();
  await tester.pump(EvRitualTiming.fade + const Duration(milliseconds: 20));
  expect(find.byType(EvLaunchRitual), findsNothing, reason: 'ритуал ушёл');
}

/// Раздел окна. Пока пустота закрывает окно, страница под ритуалом
/// за сценой — искать её нужно и там.
EvSection _section(WidgetTester tester) => tester
    .widget<EvShell>(find.byType(EvShell, skipOffstage: false))
    .controller
    .section;

Finder _inRitual(String text) => find.descendant(
  of: find.byType(EvLaunchRitual),
  matching: find.text(text, findRichText: true),
);

void main() {
  group('ход ритуала — кадры прототипа', () {
    // Значения сняты в браузере: часы прототипа подменены, анимации CSS
    // поставлены на паузу и перемотаны на то же время.
    Duration ms(num value) => Duration(microseconds: (value * 1000).round());

    test('стадии, кольцо и полоса идут линейно за 2,6 с', () {
      final start = EvRitualFrame.at(Duration.zero);
      expect(start.progress, 0);
      expect(start.stage(6), 0);
      expect(start.struck, isFalse);
      expect(start.iris, 0, reason: 'пустота закрывает окно с начала');

      final middle = EvRitualFrame.at(ms(1300));
      expect(middle.progress, .5, reason: 'полоса 50 %, кольцо 50');
      expect(middle.stage(6), 3, reason: 'на половине — граница стадий');
      expect(
        EvRitualFrame.at(ms(1299)).stage(6),
        2,
        reason: 'графический слой',
      );

      final late = EvRitualFrame.at(ms(2583.33));
      expect(late.progress, closeTo(.994, .001), reason: 'полоса 99.4 %');
      expect(late.stage(6), 5, reason: '«Запуск»');
      expect(late.struck, isFalse);

      expect(EvRitualFrame.at(ms(433)).stage(6), 0);
      expect(EvRitualFrame.at(ms(434)).stage(6), 1);
      expect(
        EvRitualFrame.at(ms(9000)).stage(6),
        5,
        reason: 'последняя держится',
      );
    });

    test('вспышка и волна — те же кривые, что анимации CSS', () {
      const window = Size(1440, 900);
      for (final (since, flash, diameter, opacity) in [
        (116.67, .580336, 1625.05, .409037),
        (416.67, .0400485, 2633.67, .0376731),
      ]) {
        final f = EvRitualFrame.at(ms(2600 + since));
        expect(f.struck, isTrue);
        expect(f.flash, closeTo(flash, .003), reason: 'вспышка через $since');
        expect(f.shockDiameter(window), closeTo(diameter, 4));
        expect(f.shockOpacity, closeTo(opacity, .003));
      }
      final end = EvRitualFrame.at(ms(2600 + 900));
      expect(end.flash, 0);
      expect(end.shockOpacity, 0);
      expect(end.shockWidth, 0);
    });

    test('ирис раскрывается за секунду от времени, а не от кадров', () {
      expect(EvRitualFrame.at(ms(2600)).iris, 0);
      expect(EvRitualFrame.at(ms(3100)).iris, closeTo(.66, 1e-9));
      expect(EvRitualFrame.at(ms(3600)).iris, closeTo(1.32, 1e-9));
      expect(EvRitualFrame.at(ms(4020)).iris, closeTo(1.32, 1e-9));
    });

    test('затемнение проявляется и уходит с ease из CSS', () {
      expect(EvRitualTiming.fadeIn.transform(60 / 300), closeTo(.295244, .002));
      expect(
        EvRitualTiming.fadeIn.transform(150 / 300),
        closeTo(.802403, .002),
      );
      // уход: значение перехода идёт от 1 к 0, через 100 мс оно 2/3
      expect(EvRitualTiming.fadeOut.transform(2 / 3), closeTo(.424138, .002));
    });

    test('шар дышит: вдох на середине цикла в 1,5 с', () {
      expect(evOrbBreath(Duration.zero), 0);
      expect(evOrbBreath(ms(375)), closeTo(.5, 1e-9));
      expect(evOrbBreath(ms(750)), 1);
      expect(evOrbBreath(ms(1500)), 0);
    });
  });

  group('выброс искр', () {
    test('каждая искра срывается вверх, крупнее и на 1,4 с', () {
      final field = EvEmberField(random: math.Random(11))
        ..resize(const Size(1440, 900), 1);
      final before = [for (final e in field.embers) (e.x, e.y, e.radius)];
      field.burst();
      expect(field.embers, hasLength(before.length));
      for (final (i, e) in field.embers.indexed) {
        expect(e.vy, inInclusiveRange(-4.0, -1.4));
        expect(e.vx.abs(), lessThanOrEqualTo(.75));
        expect((e.x, e.y), (before[i].$1, before[i].$2), reason: 'с места');
        expect(e.radius, closeTo(before[i].$3 * 1.5, 1e-9));
        expect(e.life, EvEmberField.burstLife);
        expect(e.age, 0);
      }
    });

    test('выброс виден за время ритуала, а потом угли снова обычные', () {
      // С жизнью 1400 кадров из прототипа средняя яркость через 0,6 с —
      // 0,04: искры разгорались бы десять секунд.
      final field = EvEmberField(random: math.Random(5))
        ..resize(const Size(1440, 900), 1)
        ..burst();
      for (var frame = 0; frame < 36; frame++) {
        field.step(1 / 60);
      }
      final bright =
          field.embers.map((e) => e.opacity).reduce((a, b) => a + b) /
          field.embers.length;
      expect(bright, greaterThan(.3), reason: 'в разгаре');

      for (var frame = 0; frame < 60; frame++) {
        field.step(1 / 60);
      }
      expect(
        field.embers.every((e) => e.vy > -.72),
        isTrue,
        reason: 'догоревшие родились обычными',
      );
    });
  });

  group('ритуал в окне', () {
    testWidgets('удержание запускает ритуал; окно под ним глухо к клавишам', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _app(tester);

      await _holdPlay(tester);
      expect(_inRitual('ПОДГОТОВКА СРЕДЫ'), findsOneWidget);
      expect(_inRitual('монтирование тома…'), findsOneWidget);
      expect(_inRitual('Пепельный Предел'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1250));
      expect(_inRitual('ГРАФИЧЕСКИЙ СЛОЙ'), findsOneWidget);
      expect(_inRitual('инициализация графического слоя'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pump();
      expect(_section(tester), EvSection.library, reason: 'клавиши заперты');

      await tester.pump(const Duration(milliseconds: 1350));
      expect(_inRitual('ЗАПУСК'), findsOneWidget);
      expect(_inRitual('передача управления'), findsOneWidget);

      // до ухода затемнения и сам уход
      await tester.pump(const Duration(milliseconds: 4020 - 2600));
      await tester.pump();
      await tester.pump(EvRitualTiming.fade + const Duration(milliseconds: 20));
      expect(find.byType(EvLaunchRitual), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await _settle(tester);
      expect(
        _section(tester),
        EvSection.downloads,
        reason: 'клавиши вернулись',
      );

      // Ритуал ушёл — игра идёт: герой стал статусом с таймером.
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await _settle(tester);
      expect(find.byType(EvRunningPill), findsOneWidget);
      expect(find.byType(EvPlayButton), findsNothing);

      // второй запуск начинается с первой стадии, а не с журнала прошлого
      await tester.tap(find.text('Завершить'));
      await _settle(tester);
      await _holdPlay(tester);
      expect(_inRitual('ПОДГОТОВКА СРЕДЫ'), findsOneWidget);
      expect(_inRitual('монтирование тома…'), findsOneWidget);
      await _finishRitual(tester);
    });

    for (final (width, height, top) in [
      (1440.0, 900.0, 281.25),
      (1280.0, 720.0, 191.25),
    ]) {
      testWidgets('${width.toInt()} × ${height.toInt()}: раскладка прототипа', (
        tester,
      ) async {
        _window(tester, width, height);
        await _app(tester);
        await _holdPlay(tester);
        await tester.pump(EvRitualTiming.fade);

        final cx = width / 2;
        expect(
          tester.getRect(find.byType(EvRitualCore)),
          Rect.fromLTWH(cx - 85, top, 170, 170),
        );
        final stage = tester.getRect(_inRitual('ПОДГОТОВКА СРЕДЫ'));
        expect(stage.top, top + 192);
        expect(stage.height, 16.5);
        final title = tester.getRect(_inRitual('Пепельный Предел'));
        expect(title.top, top + 218.5);
        expect(title.height, 57);
        final bar = find.descendant(
          of: find.byType(EvLaunchRitual),
          matching: find.byWidgetPredicate(
            (w) => w is CustomPaint && w.size == const Size(340, 2),
          ),
        );
        expect(
          tester.getRect(bar),
          Rect.fromLTWH(cx - 170, top + 297.5, 340, 2),
        );
        final log = tester.getRect(_inRitual('монтирование тома…'));
        expect(log.top, top + 321.5);
        expect(log.height, 16);

        // без Material текст маршрута подчёркнут жёлтым двойным
        for (final text in tester.widgetList<RichText>(
          find.descendant(
            of: find.byType(EvLaunchRitual),
            matching: find.byType(RichText),
          ),
        )) {
          expect(
            text.text.style?.decoration ?? TextDecoration.none,
            TextDecoration.none,
          );
        }

        await _finishRitual(tester);
      });
    }

    testWidgets('затемнение уходит с последним кадром, а не со сброшенным', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _app(tester);
      await _holdPlay(tester);
      await tester.pump(EvRitualTiming.full);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final ritual = find.byType(EvLaunchRitual);
      expect(ritual, findsOneWidget, reason: 'затемнение ещё уходит');
      final fade = tester.widget<FadeTransition>(
        find.ancestor(of: ritual, matching: find.byType(FadeTransition)).first,
      );
      expect(fade.opacity.value, closeTo(.424, .01));
      expect(_inRitual('ЗАПУСК'), findsOneWidget);
      expect(_inRitual('передача управления'), findsOneWidget);
      expect(
        tester.state<EvLaunchRitualState>(ritual).iris,
        greaterThanOrEqualTo(1.3),
        reason: 'ирис остаётся раскрытым',
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(ritual, findsNothing);
    });

    testWidgets('без ритуала — короткое затемнение на 0,9 с', (tester) async {
      _window(tester, 1440, 900);
      final effects = await _app(tester);
      effects.ritual = false;
      await _settle(tester);

      await _holdPlay(tester);
      await tester.pump(const Duration(milliseconds: 880));
      expect(_inRitual('ПОДГОТОВКА СРЕДЫ'), findsOneWidget);
      expect(_inRitual('монтирование тома…'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(EvLaunchRitual),
          matching: find.byType(ColoredBox),
        ),
        findsNothing,
        reason: 'без вспышки',
      );
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump();
      await tester.pump(EvRitualTiming.fade + const Duration(milliseconds: 20));
      expect(find.byType(EvLaunchRitual), findsNothing);
    });

    testWidgets('«уменьшить движение» — без ритуала и без проявления', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      _window(tester, 1440, 900);
      final effects = await _app(tester);
      expect(effects.ritual, isTrue, reason: 'в настройках ритуал включён');

      // удержание — защита, а не анимация: оно не ускоряется
      final press = await tester.startGesture(
        tester.getCenter(find.byType(EvPlayButton)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await press.up();
      await tester.pump();
      expect(find.byType(EvLaunchRitual), findsNothing, reason: '300 мс мало');
      await tester.pump(const Duration(milliseconds: 400));

      await _holdPlay(tester);
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byType(EvLaunchRitual),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, 1, reason: 'сразу, без проявления');
      final state = tester.state<EvLaunchRitualState>(
        find.byType(EvLaunchRitual),
      );
      expect(state.embers, isNull, reason: 'без выброса');

      await tester.pump(const Duration(milliseconds: 880));
      expect(find.byType(EvLaunchRitual), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump();
      expect(find.byType(EvLaunchRitual), findsNothing, reason: 'сразу ушло');
    });

    testWidgets('пока пустота закрывает окно, атмосфера под ней стоит', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _app(
        tester,
        effects: EvEffects(livingBackground: false, grain: false),
      );
      EvAtmosphereState atmosphere() => tester.state<EvAtmosphereState>(
        find.byType(EvAtmosphere, skipOffstage: false),
      );
      expect(atmosphere().isAnimating, isTrue, reason: 'угли идут');

      await _holdPlay(tester);
      await tester.pump(const Duration(milliseconds: 150));
      expect(atmosphere().isAnimating, isTrue, reason: 'окно ещё видно');
      await tester.pump(const Duration(milliseconds: 850));
      expect(atmosphere().isAnimating, isFalse, reason: 'за пустотой');
      expect(find.byType(EvShell), findsNothing, reason: 'и не рисуется');

      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pump();
      expect(atmosphere().isAnimating, isTrue, reason: 'ирис открыл окно');
      await _finishRitual(tester);
    });

    testWidgets('искры выброса — над пустотой, а не под ней', (tester) async {
      _window(tester, 1440, 900);
      // Самая яркая точка вне средней колонки, где ядро, название и
      // полоса, и непрозрачность середины окна. Без искр там ровно пустота.
      Future<(int, int)> brightestAside({required bool sparks}) async {
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: buildEvTheme(),
            home: RepaintBoundary(
              key: boundary,
              child: EvLaunchRitual(
                key: ValueKey(sparks),
                title: 'Пепельный Предел',
                stages: sampleLaunchStages,
                sparks: sparks,
              ),
            ),
          ),
        );
        for (var frame = 0; frame < 36; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final data = await tester.runAsync(() async {
          final image = await render.toImage();
          final bytes = await image.toByteData();
          image.dispose();
          return bytes!;
        });
        var brightest = 0;
        for (var y = 0; y < 900; y += 1) {
          for (var x = 0; x < 1440; x += 1) {
            if (x >= 400 && x < 1040) continue;
            brightest = math.max(brightest, data!.getUint8((y * 1440 + x) * 4));
          }
        }
        final middle = data!.getUint8((450 * 1440 + 720) * 4 + 3);
        await tester.pumpWidget(const SizedBox());
        return (brightest, middle);
      }

      final ground = (EvColors.magma.ground.r * 255).round();
      final (still, middle) = await brightestAside(sparks: false);
      expect(still, lessThanOrEqualTo(ground + 2));
      expect(middle, 255, reason: 'пустота без отверстия посередине');
      expect((await brightestAside(sparks: true)).$1, greaterThan(ground + 60));
    });

    testWidgets(
      'палитра: Shift+Enter запускает, что не на диске — к загрузкам',
      (tester) async {
        _window(tester, 1440, 900);
        await _app(tester);

        Future<void> launchFromPalette(String query) async {
          await tester.sendKeyEvent(LogicalKeyboardKey.slash);
          await _settle(tester);
          expect(find.text('⇧↵ запустить'), findsOneWidget);
          await tester.enterText(find.byType(TextField), query);
          await tester.pump();
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
          await tester.pump();
        }

        await launchFromPalette('орбита');
        await _settle(tester);
        expect(find.byType(EvPalette), findsNothing);
        expect(find.byType(EvLaunchRitual), findsNothing);
        expect(_section(tester), EvSection.downloads);

        await launchFromPalette('пепел');
        expect(find.byType(EvLaunchRitual), findsOneWidget);
        expect(_inRitual('Пепельный Предел'), findsOneWidget);
        await tester.pump();
        await _finishRitual(tester);
        expect(
          _section(tester),
          EvSection.downloads,
          reason: 'раздел не тронут',
        );
      },
    );
  });
}
