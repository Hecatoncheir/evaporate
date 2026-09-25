import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:evaporate/ui/ev/atmosphere/ember_field.dart';
import 'package:evaporate/ui/ev/atmosphere/ev_atmosphere.dart';
import 'package:evaporate/ui/ev/design/effects.dart';
import 'package:evaporate/ui/ev/design/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<EvAtmosphereState> _pumpAtmosphere(
  WidgetTester tester, {
  EvEffects? effects,
}) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  const atmosphere = EvAtmosphere(child: SizedBox.expand());
  await tester.pumpWidget(
    MaterialApp(
      theme: buildEvTheme(),
      home: effects == null
          ? atmosphere
          : EvEffectsScope(effects: effects, child: atmosphere),
    ),
  );
  // Загрузка шейдера завершилась в настоящей зоне (setUpAll), и её
  // продолжение ждёт там же: нужен один реальный оборот цикла событий.
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
  return tester.state<EvAtmosphereState>(find.byType(EvAtmosphere));
}

EvEffects _effects(WidgetTester tester, {bool throttle = true}) {
  final effects = EvEffects(throttleInBackground: throttle);
  addTearDown(effects.dispose);
  return effects;
}

void main() {
  // Шейдер грузится один раз на приложение, и грузить его нужно в настоящей
  // зоне: будущее, начатое внутри testWidgets с подменным временем, в другом
  // тесте не завершится никогда.
  ui.FragmentProgram? plume;
  setUpAll(() async {
    plume = await EvPlumeProgram.load().timeout(const Duration(seconds: 30));
  });

  test('шейдер плюма собирается и загружается', () {
    expect(plume, isNotNull);
  });

  // Плюм прототипа был включён, но невидим: холст без предумноженной альфы
  // умножал на неё в третий раз, и вклад не превышал 1 % яркости. Вариант
  // «альфа один раз» — наоборот, мутный дым на весь экран. Здесь яркость
  // кадра держится между этими крайностями.
  test('плюм виден, но не заливает экран', () async {
    const w = 480, h = 300;
    final colors = EvSkin.magma.colors;
    final shader = plume!.fragmentShader();
    setPlumeUniforms(
      shader,
      frame: const Size(480, 300),
      time: 30,
      pointer: const Offset(0.5, 0.5),
      colors: colors,
    );
    final recorder = ui.PictureRecorder();
    Canvas(recorder)
      ..drawRect(
        const Rect.fromLTWH(0, 0, 480, 300),
        Paint()..color = colors.ground,
      )
      ..drawRect(const Rect.fromLTWH(0, 0, 480, 300), Paint()..shader = shader);
    final image = await recorder.endRecording().toImage(w, h);
    final pixels = (await image.toByteData())!;
    var sum = 0, top = 0, bottom = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final red = pixels.getUint8((y * w + x) * 4);
        sum += red;
        if (y < h ~/ 4) top += red;
        if (y >= h * 3 ~/ 4) bottom += red;
      }
    }
    final ground = (colors.ground.r * 255).round();
    final lift = sum / (w * h) - ground;
    expect(lift, greaterThan(3), reason: 'виден');
    expect(lift, lessThan(20), reason: 'не заливает');
    expect(bottom, greaterThan(top * 2), reason: 'пар поднимается снизу');
    shader.dispose();
    image.dispose();
  });

  group('угли', () {
    test('число искр идёт от ширины окна и уровня эффектов', () {
      expect(EvEmberField.countFor(1440, 1), 85);
      expect(EvEmberField.countFor(1440, 0.5), 42);
      expect(EvEmberField.countFor(400, 1), 34, reason: 'не меньше 34');
      expect(EvEmberField.countFor(2560, 1.6), 166, reason: '104 × «Макс»');
    });

    test('угли поднимаются через весь экран, а не живут у нижней кромки', () {
      // В прототипе жизнь считалась в миллисекундах, и через пару секунд
      // все искры оказывались в нижних 30 px окна.
      final field = EvEmberField(random: math.Random(7))
        ..resize(const Size(1440, 900), 1);
      for (var frame = 0; frame < 60 * 12; frame++) {
        field.step(1 / 60);
      }
      final ys = field.embers.map((e) => e.y).toList();
      expect(ys.reduce(math.min), lessThan(300), reason: 'доходят до верха');
      final inside = ys.where((y) => y < 900 - 30).length;
      expect(inside / ys.length, greaterThan(0.8), reason: 'большинство видно');
    });

    test('длинная пауза не подбрасывает угли разом', () {
      final field = EvEmberField(random: math.Random(3))
        ..resize(const Size(1440, 900), 1);
      final before = field.embers.map((e) => e.y).toList();
      field.step(10); // окно свернули на 10 секунд
      final moved = [
        for (var i = 0; i < before.length; i++)
          (field.embers[i].y - before[i]).abs(),
      ];
      expect(
        moved.reduce(math.max),
        lessThan(10),
        reason: 'шаг режется до 64 мс',
      );
    });
  });

  group('атмосфера', () {
    testWidgets('без EvEffectsScope кадры не идут', (tester) async {
      final state = await _pumpAtmosphere(tester);
      expect(state.isAnimating, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('живой фон идёт кадрами, а время плюма растёт', (tester) async {
      final state = await _pumpAtmosphere(tester, effects: _effects(tester));
      expect(state.isAnimating, isTrue);
      expect(state.hasPlume, isTrue, reason: 'кадры рисуют настоящий плюм');
      final start = state.time;
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(state.time - start, closeTo(0.48, 0.05));
      expect(
        tester.takeException(),
        isNull,
        reason: 'кадры рисуются без ошибок',
      );
    });

    testWidgets('выключенные фон и искры останавливают кадры', (tester) async {
      final effects = _effects(tester);
      final state = await _pumpAtmosphere(tester, effects: effects);
      effects
        ..livingBackground = false
        ..sparks = false;
      await tester.pump();
      expect(state.isAnimating, isFalse);

      effects.sparks = true;
      await tester.pump();
      expect(state.isAnimating, isTrue, reason: 'одних искр достаточно');
    });

    testWidgets('в неактивном окне 30 к/с, в свёрнутом — ни одного кадра', (
      tester,
    ) async {
      final state = await _pumpAtmosphere(tester, effects: _effects(tester));
      final binding = tester.binding;

      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(state.isThrottled, isTrue);
      final t0 = state.time;
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.time, greaterThan(t0), reason: 'таймер ведёт кадры');

      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(state.isAnimating, isFalse);
      final t1 = state.time;
      await tester.pump(const Duration(milliseconds: 500));
      expect(state.time, t1);

      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(state.isAnimating, isTrue);
      expect(state.isThrottled, isFalse);
    });

    testWidgets('без ограничения неактивное окно идёт на полной частоте', (
      tester,
    ) async {
      final state = await _pumpAtmosphere(
        tester,
        effects: _effects(tester, throttle: false),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(state.isAnimating, isTrue);
      expect(state.isThrottled, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
    });

    testWidgets('«уменьшить движение» — неподвижный кадр прототипа', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final state = await _pumpAtmosphere(tester, effects: _effects(tester));
      expect(state.isAnimating, isFalse);
      expect(state.time, 8);
    });

    testWidgets('страница под непрозрачным маршрутом не тратит кадры', (
      tester,
    ) async {
      final state = await _pumpAtmosphere(tester, effects: _effects(tester));
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(MaterialPageRoute<void>(builder: (_) => const SizedBox()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(state.isAnimating, isFalse);

      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(state.isAnimating, isTrue);
    });
  });
}
