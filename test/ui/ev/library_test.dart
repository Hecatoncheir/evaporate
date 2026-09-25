import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:evaporate/ui/ev/art/ev_art.dart';
import 'package:evaporate/ui/ev/art/key_art.dart';
import 'package:evaporate/ui/ev/atmosphere/ev_atmosphere.dart';
import 'package:evaporate/ui/ev/atmosphere/ev_pointer.dart';
import 'package:evaporate/ui/ev/data/sample_data.dart';
import 'package:evaporate/ui/ev/data/sample_downloads.dart';
import 'package:evaporate/ui/ev/data/sample_friends.dart';
import 'package:evaporate/ui/ev/design/effects.dart';
import 'package:evaporate/ui/ev/design/theme.dart';
import 'package:evaporate/ui/ev/design/tokens.dart';
import 'package:evaporate/ui/ev/downloads/download_data.dart';
import 'package:evaporate/ui/ev/ev_app.dart';
import 'package:evaporate/ui/ev/library/ev_hero.dart';
import 'package:evaporate/ui/ev/library/ev_session_row.dart';
import 'package:evaporate/ui/ev/library/ev_side_cards.dart';
import 'package:evaporate/ui/ev/library/library_layout.dart';
import 'package:evaporate/ui/ev/screens/library_page.dart';
import 'package:evaporate/ui/ev/util/units.dart';
import 'package:evaporate/ui/ev/widgets/ev_game_card.dart';
import 'package:evaporate/ui/ev/widgets/ev_play_button.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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

/// Средние цвета клеток сетки, с предумноженной альфой, как их считал
/// скрипт в прототипе.
Future<List<List<int>>> _cells(ui.Image image, int columns, int rows) async {
  final data = (await image.toByteData())!;
  final w = image.width, h = image.height;
  final cw = w / columns, ch = h / rows;
  return [
    for (var gy = 0; gy < rows; gy++)
      for (var gx = 0; gx < columns; gx++)
        () {
          final sum = [0, 0, 0, 0];
          var n = 0;
          for (var y = (gy * ch).floor(); y < ((gy + 1) * ch).floor(); y++) {
            for (var x = (gx * cw).floor(); x < ((gx + 1) * cw).floor(); x++) {
              for (var k = 0; k < 4; k++) {
                sum[k] += data.getUint8((y * w + x) * 4 + k);
              }
              n++;
            }
          }
          return [for (final s in sum) (s / n).round()];
        }(),
  ];
}

/// Средняя и наибольшая разница по каналам.
(double, int) _difference(
  List<List<int>> mine,
  List<List<int>> reference,
  int channels,
) {
  var total = 0, worst = 0;
  for (var i = 0; i < reference.length; i++) {
    for (var k = 0; k < channels; k++) {
      final d = (mine[i][k] - reference[i][k]).abs();
      total += d;
      worst = math.max(worst, d);
    }
  }
  return (total / (reference.length * channels), worst);
}

List<List<int>> _fixture(String file, String key) {
  final json = jsonDecode(
    File('test/ui/ev/fixtures/$file').readAsStringSync(),
  ) as Map<String, dynamic>;
  return [
    for (final cell in (json[key] as Map<String, dynamic>)['cells'] as List)
      (cell as List).cast<int>(),
  ];
}

void main() {
  group('ключевой кадр', () {
    test('генератор — тот же mulberry32, что rng32 прототипа', () {
      // Эталон посчитан по коду прототипа с арифметикой int32 из JS.
      const reference = {
        0: [
          0.26642920868471265,
          0.0003297457005828619,
          0.2232720274478197,
          0.1462021479383111,
        ],
        1207: [
          0.09094201843254268,
          0.23204997787252069,
          0.7282224474474788,
          0.4262719911057502,
        ],
        9314: [
          0.5209267281461507,
          0.4277727387379855,
          0.7500699511729181,
          0.44234947650693357,
        ],
      };
      for (final MapEntry(key: seed, value: values) in reference.entries) {
        final rnd = EvArtRandom(seed);
        expect([for (final _ in values) rnd.next()], values, reason: '$seed');
      }
    });

    // Сетки сняты в браузере с холстов прототипа: слои героя «Пепельного
    // Предела» 1280 × 720 клетками 80 px и обложки 300 × 400 клетками
    // 50 px. Небо и обложки там — JPEG, отсюда разница в пару единиц.
    test('слои героя — те же кадры, что в прототипе', () async {
      for (final (layer, key) in [
        (EvHeroLayer.sky, 'sky'),
        (EvHeroLayer.ridges, 'mid'),
        (EvHeroLayer.ledge, 'sub'),
      ]) {
        final image = EvArtCache.heroLayer(layer, EvCoverPalette.ash, 1207, 1);
        expect([image.width, image.height], [1280, 720]);
        final (mean, worst) = _difference(
          await _cells(image, 16, 9),
          _fixture('prototype_hero_ash_1207.json', key),
          4,
        );
        expect(mean, lessThan(1), reason: '$key: средняя разница');
        expect(worst, lessThanOrEqualTo(4), reason: '$key: худшая клетка');
      }
    });

    test('обложки — те же кадры, что в прототипе', () async {
      for (final (key, palette, seed) in [
        ('ashen', EvCoverPalette.ash, 1207),
        ('depth', EvCoverPalette.deepSea, 9314),
        ('orbita', EvCoverPalette.orbit, 8802),
      ]) {
        final image = EvArtCache.cover(palette, seed, 300, 400);
        final (mean, worst) = _difference(
          await _cells(image, 6, 8),
          _fixture('prototype_covers.json', key),
          3,
        );
        expect(mean, lessThan(1), reason: '$key: средняя разница');
        expect(worst, lessThanOrEqualTo(4), reason: '$key: худшая клетка');
      }
    });

    test('размытия масштабируются вместе с растром', () async {
      // Иначе на экране с плотностью 2 дымка стала бы вдвое резче.
      final base = await _cells(
        EvArtCache.heroLayer(EvHeroLayer.sky, EvCoverPalette.ash, 1207, 1),
        16,
        9,
      );
      final dense = await _cells(
        EvArtCache.heroLayer(EvHeroLayer.sky, EvCoverPalette.ash, 1207, 2),
        16,
        9,
      );
      expect(_difference(dense, base, 3).$1, lessThan(1));
    });

    test('масштаб растра идёт ступенями по четверти', () {
      expect(EvHeroArtPainter.rasterScale(1.02), 1.25);
      expect(EvHeroArtPainter.rasterScale(1.25), 1.25);
      expect(EvHeroArtPainter.rasterScale(0.2), 0.5, reason: 'не мельче');
      expect(EvHeroArtPainter.rasterScale(4), 2.5, reason: 'не крупнее');
    });
  });

  group('раскладка — ступени прототипа', () {
    // Числа сняты с прототипа в браузере на тех же размерах окна.
    test('1440 × 900', () {
      final m = EvLibraryLayout.of(const Size(1440, 900));
      expect(m.heroHeight, 468);
      expect(m.titleSize, 68);
      expect([m.bodySide, m.bodyBottom], [44, 40]);
      expect(m.bodyMaxWidth(1293), 620);
      expect([m.blurbSize, m.blurbChars], [14, 46]);
      expect(m.buttonHeight, 56);
      expect(m.showSessions, isTrue);
      expect(m.cardWidth, 178);
      expect(m.sideWidth, 0);
    });

    test('1280 × 720 — герой ужат, «Продолжить» сложено', () {
      final m = EvLibraryLayout.of(const Size(1280, 720));
      expect(m.heroHeight, 300);
      expect(m.titleSize, closeTo(43.52, 1e-9));
      expect([m.bodySide, m.bodyBottom, m.bodyGap], [32, 18, 11]);
      expect([m.blurbSize, m.buttonHeight], [13, 50]);
      expect(m.showSessions, isFalse);
      expect(m.cardWidth, 152);
      expect(EvLibraryLayout.of(const Size(1100, 700)).cardWidth, 134);
    });

    test('1801 × 1205 — правая колонка, ширина сильнее высоты', () {
      final m = EvLibraryLayout.of(const Size(1801, 1205));
      expect(m.heroHeight, 520);
      expect(m.titleSize, closeTo(64.836, 1e-9));
      expect(m.bodyMaxWidth(1211), 760);
      expect([m.blurbSize, m.blurbChars], [15.5, 52]);
      expect([m.cardWidth, m.sideWidth, m.sessionMinWidth], [206, 384, 330]);
      expect(
        EvLibraryLayout.of(const Size(1920, 720)).heroHeight,
        520,
        reason: 'правило ширины объявлено позже высоты',
      );
    });

    test('2560 × 1440', () {
      final m = EvLibraryLayout.of(const Size(2560, 1440));
      expect(m.heroHeight, closeTo(604.8, 1e-9));
      expect(m.titleSize, 82);
      expect(m.bodyMaxWidth(1400), 812);
      expect([m.cardWidth, m.sideWidth], [224, 420]);
    });
  });

  group('библиотека в окне', () {
    testWidgets('1440 × 900: герой, «Продолжить» и полки', (tester) async {
      _window(tester, 1440, 900);
      await _app(tester);

      final hero = tester.getRect(find.byType(EvHero));
      expect(hero.height, 468);
      expect(
        hero.left,
        EvSpace.railWidth + EvSpace.gutterFor(tester.view.physicalSize),
      );
      expect(find.text('ПРОДОЛЖИТЬ · СЫГРАНО 284 Ч 10 МИН'), findsOneWidget);
      expect(find.text('Пепельный'), findsOneWidget);
      expect(find.text('Предел'), findsOneWidget);
      expect(find.text('Установлена'), findsOneWidget);

      // текст героя прижат к левому и нижнему полю: 1 px рамки и отступ
      final play = tester.getRect(find.byType(EvPlayButton));
      expect(play.height, 56);
      expect(play.bottom, closeTo(hero.bottom - 1 - 40, 0.01));
      expect(play.left, closeTo(hero.left + 1 + 44, 0.01));

      expect(find.byType(EvSessionRow), findsNWidgets(3));
      expect(find.text('3 сессии'), findsOneWidget);
      expect(find.text('64 ч · вчера в 23:40'), findsOneWidget);
      expect(find.text('8 установлено'), findsOneWidget);
      expect(find.text('СКОРО НА ДИСКЕ'), findsOneWidget);
      expect(tester.getSize(find.byType(EvGameCard).first).width, 178);
      expect(find.byType(EvFriendsCard), findsNothing);
    });

    testWidgets('1280 × 720: герой 300 px, «Продолжить» сложено', (
      tester,
    ) async {
      _window(tester, 1280, 720);
      await _app(tester);

      final hero = tester.getRect(find.byType(EvHero));
      expect(hero.height, 300);
      final play = tester.getRect(find.byType(EvPlayButton));
      expect(play.height, 50);
      expect(play.bottom, closeTo(hero.bottom - 1 - 18, 0.01));
      expect(play.left, closeTo(hero.left + 1 + 32, 0.01));
      expect(find.byType(EvSessionRow), findsNothing);
      expect(tester.getSize(find.byType(EvGameCard).first).width, 152);
    });

    for (final (width, height, side, card) in [
      (1920.0, 1080.0, 384.0, 206.0),
      (2560.0, 1440.0, 420.0, 224.0),
    ]) {
      testWidgets('${width.toInt()} × ${height.toInt()}: правая колонка', (
        tester,
      ) async {
        _window(tester, width, height);
        await _app(tester);
        final gutter = EvSpace.gutterFor(Size(width, height));

        final friends = tester.getRect(find.byType(EvFriendsCard));
        final hero = tester.getRect(find.byType(EvHero));
        expect(friends.width, side);
        expect(friends.right, width - gutter);
        expect(friends.top, hero.top, reason: 'колонка начинается с героем');
        expect(hero.right, friends.left - gutter);
        expect(tester.getSize(find.byType(EvGameCard).first).width, card);

        expect(find.text('Антон К.'), findsOneWidget);
        expect(find.text('41 % · 592 КБ/с'), findsOneWidget);
        expect(find.text('66 % · 1.03 МБ/с'), findsOneWidget);
        expect(find.text('приём 1.62 МБ/с'), findsOneWidget);
        expect(find.text('2 / 3'), findsOneWidget);
      });
    }
  });

  group('параллакс', () {
    Future<void> moveMouse(WidgetTester tester, Offset to) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(700, 450));
      await mouse.moveTo(to);
    }

    EvHeroArtPainter art(WidgetTester tester) => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<EvHeroArtPainter>()
        .single;

    testWidgets('слои и текст идут за курсором, кадры потом встают', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _app(
        tester,
        effects: EvEffects(
          livingBackground: false,
          sparks: false,
          grain: false,
        ),
      );
      final atmosphere = tester.state<EvAtmosphereState>(
        find.byType(EvAtmosphere),
      );
      const eyebrow = 'ПРОДОЛЖИТЬ · СЫГРАНО 284 Ч 10 МИН';
      final before = tester.getTopLeft(find.text(eyebrow));
      expect(atmosphere.isAnimating, isFalse, reason: 'курсор ещё не двигался');

      // из центра окна в левый верхний угол
      await moveMouse(tester, Offset.zero);
      await tester.pump();
      expect(atmosphere.isAnimating, isTrue, reason: 'кадры ради параллакса');
      for (var i = 0; i < 400 && atmosphere.isAnimating; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(atmosphere.isAnimating, isFalse, reason: 'курсор догнан');

      expect(art(tester).pointer!.value, Offset.zero);
      // текст идёт вместе с курсором на 8 px, по вертикали на 0,55 от этого;
      // до движения курсор стоял в (0,5; 0,4), как в прототипе
      final after = tester.getTopLeft(find.text(eyebrow));
      expect(after.dx - before.dx, closeTo(-4, 0.01));
      expect(after.dy - before.dy, closeTo(-2.2 + .44, 0.01));
    });

    test('слой уступа сдвигается на 30 px, небо — на 5', () {
      const size = Size(1000, 400);
      final centered = EvHeroArtPainter.layerRect(
        EvHeroLayer.ledge,
        size,
        null,
      );
      expect(centered.center, size.center(Offset.zero));
      expect(
        EvHeroArtPainter.layerRect(
              EvHeroLayer.ledge,
              size,
              Offset.zero,
            ).center -
            centered.center,
        const Offset(15, 8.25),
      );
      final sky =
          EvHeroArtPainter.layerRect(
            EvHeroLayer.sky,
            size,
            const Offset(1, 1),
          ).center -
          size.center(Offset.zero);
      expect(sky.dx, closeTo(-2.5, 1e-9));
      expect(sky.dy, closeTo(-1.375, 1e-9));
      // запас 6 % и кадр 16 : 9 по «cover»
      expect(centered.width, 1120);
      expect(centered.height, 630);
    });

    testWidgets('выключен в настройках — текст и слои на месте', (
      tester,
    ) async {
      _window(tester, 1440, 900);
      await _app(tester);
      const eyebrow = 'ПРОДОЛЖИТЬ · СЫГРАНО 284 Ч 10 МИН';
      final before = tester.getTopLeft(find.text(eyebrow));
      await moveMouse(tester, Offset.zero);
      await _settle(tester);
      expect(tester.getTopLeft(find.text(eyebrow)), before);
      expect(art(tester).pointer, isNull);
      expect(
        tester.state<EvAtmosphereState>(find.byType(EvAtmosphere)).isAnimating,
        isFalse,
      );
    });

    testWidgets('«уменьшить движение» — параллакса нет', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      _window(tester, 1440, 900);
      await _app(
        tester,
        effects: EvEffects(
          livingBackground: false,
          sparks: false,
          grain: false,
        ),
      );
      expect(art(tester).pointer, isNull);
      expect(art(tester).charge, isNull, reason: 'и марева тоже');
    });
  });

  group('удержание «Играть»', () {
    Widget page(EvEffects effects, ValueChanged<SampleGame> onLaunch) =>
        MaterialApp(
          theme: buildEvTheme(),
          home: EvEffectsScope(
            effects: effects,
            child: Scaffold(
              body: LibraryPage(
                games: sampleLibrary,
                hero: sampleHero,
                sessions: sampleSessions,
                friends: sampleFriends,
                friendsOnline: sampleFriendsOnline,
                downloads: sampleDownloadsFor(EvDownloadsState.active),
                onLaunch: onLaunch,
              ),
            ),
          ),
        );

    testWidgets('герой берёт удержание из настроек', (tester) async {
      _window(tester, 1440, 900);
      final effects = EvEffects.still();
      addTearDown(effects.dispose);
      SampleGame? launched;
      await tester.pumpWidget(page(effects, (g) => launched = g));
      await _settle(tester);

      await tester.tap(find.byType(EvPlayButton));
      await _settle(tester);
      expect(launched, isNull, reason: 'нажатие не запускает');

      effects.holdToPlay = false;
      await _settle(tester);
      await tester.tap(find.byType(EvPlayButton));
      await tester.pump();
      expect(launched, sampleHero);
    });

    testWidgets('с клавиатуры: пробел держит заряд, отпускание сбрасывает', (
      tester,
    ) async {
      var launched = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildEvTheme(),
          home: Scaffold(
            body: Center(child: EvPlayButton(onLaunch: () => launched++)),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      Future<void> hold(LogicalKeyboardKey key, Duration duration) async {
        await tester.sendKeyDownEvent(key);
        await tester.pump();
        await tester.pump(duration);
        await tester.sendKeyUpEvent(key);
        await tester.pump(const Duration(milliseconds: 400));
      }

      await hold(LogicalKeyboardKey.space, const Duration(milliseconds: 300));
      expect(launched, 0, reason: 'отпустили раньше — заряд сброшен');

      final full = EvMotion.hold + const Duration(milliseconds: 40);
      await hold(LogicalKeyboardKey.space, full);
      expect(launched, 1, reason: 'пробел');
      await hold(LogicalKeyboardKey.enter, full);
      expect(launched, 2, reason: 'Enter; отпускание после запуска — ничего');
    });

    test('марево: пока идёт заряд, кадр дрожит, после — как был', () async {
      final charge = ValueNotifier<double>(0);
      addTearDown(charge.dispose);
      final painter = EvHeroArtPainter(
        palette: EvCoverPalette.ash,
        seed: 1207,
        devicePixelRatio: 1,
        pointer: null,
        charge: charge,
        clock: Stopwatch()..start(),
      );
      Future<List<List<int>>> frame() async {
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), const Size(640, 240));
        final image = await recorder.endRecording().toImage(640, 240);
        final cells = await _cells(image, 32, 12);
        image.dispose();
        return cells;
      }

      final still = await frame();
      charge.value = .5;
      final hot = await frame();
      expect(_difference(hot, still, 3).$2, greaterThan(2), reason: 'дрожит');
      charge.value = 0;
      expect(_difference(await frame(), still, 3).$2, 0, reason: 'как был');
    });
  });

  group('данные', () {
    test('скорость, время и производные библиотеки', () {
      expect(formatRate(592), '592 КБ/с');
      expect(formatRate(1030), '1.03 МБ/с');
      expect(formatRate(1622, digits: 1), '1.6 МБ/с');
      expect(
        formatPlayed(const Duration(hours: 24, minutes: 10)),
        '24 ч 10 мин',
      );
      expect(formatPlayed(const Duration(hours: 6)), '6 ч');

      expect(sampleSessions, isNot(contains(sampleHero)));
      expect(sampleSessions.map((g) => g.title), [
        'Глубина 9',
        'Красный Меридиан',
        'Волчья Тропа',
      ]);
      expect(sampleDownloadsActive, 2);
      expect(sampleRateKb, 1622);
      expect(sampleHero.chips.first, ('Установлена', true));
      expect(
        sampleLibrary.firstWhere((g) => g.title == 'Орбита 7').badge,
        '41 %',
      );
    });

    test('курсор догоняет цель одинаково на 60 и 120 Гц и встаёт точно', () {
      final at60 = EvPointer(), at120 = EvPointer();
      addTearDown(at60.dispose);
      addTearDown(at120.dispose);
      at60.target = at120.target = Offset.zero;
      for (var i = 0; i < 30; i++) {
        at60.advance(1 / 60);
        at120
          ..advance(1 / 120)
          ..advance(1 / 120);
      }
      expect((at60.value - at120.value).distance, lessThan(1e-9));
      expect(at60.settling, isTrue);
      for (var i = 0; i < 600; i++) {
        at60.advance(1 / 60);
      }
      expect(at60.value, Offset.zero);
      expect(at60.settling, isFalse);
    });
  });
}
