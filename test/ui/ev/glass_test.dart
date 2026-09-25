import 'dart:ui' as ui;

import 'package:evaporate/l10n/app_localizations.dart';
import 'package:evaporate/ui/ev/design/effects.dart';
import 'package:evaporate/ui/ev/design/theme.dart';
import 'package:evaporate/ui/ev/design/tokens.dart';
import 'package:evaporate/ui/ev/ev_app.dart';
import 'package:evaporate/ui/ev/glass/ev_droplet.dart';
import 'package:evaporate/ui/ev/glass/ev_glass.dart';
import 'package:evaporate/ui/ev/glass/ev_scroll_edge.dart';
import 'package:evaporate/ui/ev/glass/glass_lens.dart';
import 'package:evaporate/ui/ev/glass/glass_surface.dart';
import 'package:evaporate/ui/ev/library/ev_hero.dart';
import 'package:evaporate/ui/ev/screens/library_page.dart';
import 'package:evaporate/ui/ev/shell/ev_hints_bar.dart';
import 'package:evaporate/ui/ev/shell/ev_rail.dart';
import 'package:evaporate/ui/ev/shell/ev_section.dart';
import 'package:evaporate/ui/ev/shell/ev_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

Widget _app(EvEffects effects) => EvaporateApp(effects: effects);

EvEffects _still(WidgetTester tester) {
  final effects = EvEffects.still();
  addTearDown(effects.dispose);
  return effects;
}

Future<void> _window(WidgetTester tester, double w, double h) async {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('материал', () {
    testWidgets('стекло читает фон, а без него — нет', (tester) async {
      await _window(tester, 1440, 900);
      final effects = _still(tester);
      await tester.pumpWidget(_app(effects));
      await _settle(tester);

      final withGlass = tester.widgetList(find.byType(BackdropFilter)).length;
      expect(withGlass, greaterThan(3), reason: 'рейл и полосы — стеклянные');

      effects.glass = false;
      await _settle(tester);
      expect(
        find.byType(BackdropFilter),
        findsNothing,
        reason: 'выключенное стекло не должно стоить ни одного чтения фона',
      );
    });

    testWidgets('стекло без фона держится заливкой поплотнее', (tester) async {
      await _window(tester, 600, 400);
      final effects = _still(tester);
      Color fillOf(WidgetTester tester) => tester
          .renderObject<RenderGlassSurface>(find.byType(EvGlassSurface))
          .fill;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildEvTheme(),
          home: EvEffectsScope(
            effects: effects,
            child: const Scaffold(
              body: Center(
                child: EvGlass(child: SizedBox(width: 200, height: 80)),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      final glass = fillOf(tester);

      effects.glass = false;
      await _settle(tester);
      expect(fillOf(tester).a, greaterThan(glass.a));
    });

    test('преломление обещано ровно там, где движок его умеет', () {
      expect(EvGlassLens.supported, ui.ImageFilter.isShaderFilterSupported);
      // В тестах движок — Skia, значит линза недоступна и стекло матовое.
      if (!EvGlassLens.supported) expect(EvGlassLens.ready.value, isFalse);
    });
  });

  group('свет', () {
    test('кромка светится только на заданных сторонах', () async {
      // Яркость столбца посередине высоты: левый и правый край полосы.
      Future<(int, int)> edges(Set<AxisDirection>? sides) async {
        const size = Size(100, 60);
        final rect = Offset.zero & size;
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)
          ..drawRect(rect, Paint()..color = const Color(0xFF000000));
        paintGlassRim(
          canvas,
          RRect.fromRectAndRadius(rect.deflate(4), Radius.zero),
          EvGlassLight.of(rect, null, size),
          EvGlassStyle.frost,
          const Color(0xFFFFFFFF),
          sides: sides,
        );
        final image = recorder.endRecording().toImageSync(100, 60);
        final bytes = (await image.toByteData())!;
        int red(int x) => bytes.getUint8((30 * 100 + x) * 4);
        final out = (red(4), red(95));
        image.dispose();
        return out;
      }

      final right = await edges({AxisDirection.right});
      expect(right.$1, 0, reason: 'слева кромки нет');
      expect(right.$2, greaterThan(0), reason: 'справа есть');
      final all = await edges(null);
      expect(all.$1, greaterThan(0), reason: 'без сторон — весь периметр');
      expect(all.$2, greaterThan(0));
    });

    const window = Size(1280, 720);
    const rect = Rect.fromLTWH(540, 300, 200, 120);

    test('кромка со стороны курсора светится ярче дальней', () {
      // курсор слева сверху от стекла
      final light = EvGlassLight.of(rect, const Offset(0.1, 0.1), window);
      final top = light.intensity(rect.topCenter, const Offset(0, -1));
      final bottom = light.intensity(rect.bottomCenter, const Offset(0, 1));
      final left = light.intensity(rect.centerLeft, const Offset(-1, 0));
      final right = light.intensity(rect.centerRight, const Offset(1, 0));
      expect(top, greaterThan(bottom * 1.5));
      expect(left, greaterThan(right * 1.5));
    });

    test('курсор ушёл на другую сторону — блик ушёл за ним', () {
      final leftLight = EvGlassLight.of(rect, const Offset(0.05, 0.5), window);
      final rightLight = EvGlassLight.of(rect, const Offset(0.95, 0.5), window);
      const normal = Offset(1, 0);
      expect(
        rightLight.intensity(rect.centerRight, normal),
        greaterThan(leftLight.intensity(rect.centerRight, normal)),
      );
    });

    test('без курсора свет стоит слева сверху', () {
      final light = EvGlassLight.of(rect, null, window);
      expect(light.point.dx, lessThan(rect.left));
      expect(light.point.dy, lessThan(rect.top));
    });
  });

  group('капля', () {
    const from = Rect.fromLTWH(6, 62, 48, 44);
    const to = Rect.fromLTWH(6, 206, 48, 44);

    test('на концах пути капля ровно на месте', () {
      expect(evDropletRect(from, to, 0), from);
      expect(evDropletRect(from, to, 1), to);
    });

    test('в полёте капля вытянута по движению и сужена поперёк', () {
      final mid = evDropletRect(from, to, 0.45);
      expect(mid.height, greaterThan(from.height * 1.2));
      expect(mid.width, lessThan(from.width));
      // передний край уже ближе к цели, чем задний
      final leadPassed = (mid.bottom - from.bottom) / (to.bottom - from.bottom);
      final trailPassed = (mid.top - from.top) / (to.top - from.top);
      expect(leadPassed, greaterThan(trailPassed));
    });

    test('капля вверх вытягивается так же', () {
      final mid = evDropletRect(to, from, 0.45);
      expect(mid.height, greaterThan(from.height * 1.2));
      final leadPassed = (to.top - mid.top) / (to.top - from.top);
      final trailPassed = (to.bottom - mid.bottom) / (to.bottom - from.bottom);
      expect(leadPassed, greaterThan(trailPassed));
    });

    test('капля рейла встаёт на кнопку выбранного раздела', () {
      const height = 884.0;
      for (final (i, section) in EvSection.primary.indexed) {
        final rect = EvRail.dropletRect(section, height);
        expect(rect.top, EvRail.itemTop(i));
        expect(rect.size, const Size(EvRail.itemWidth, EvRail.itemHeight));
      }
      expect(
        EvRail.dropletRect(EvSection.friends, height).top,
        EvRail.friendsTop(height),
      );
      // на профиле капля центрируется на аватаре
      expect(
        EvRail.dropletRect(EvSection.profile, height).center.dy,
        EvRail.avatarTop(height) + EvRail.avatarSize / 2,
      );
    });

    testWidgets('капля переезжает к выбранному разделу', (tester) async {
      await _window(tester, 1440, 900);
      await tester.pumpWidget(_app(_still(tester)));
      await _settle(tester);

      Rect droplet() => tester.getRect(find.byType(EvDroplet).first);
      final library = droplet();
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is EvRailItem && w.section == EvSection.saves,
        ),
      );
      await _settle(tester);
      expect(droplet().top, greaterThan(library.top));
    });
  });

  group('каркас', () {
    // Верхняя полоса — своё стекло, строка подсказок — иней.
    for (final blur in [EvTopBar.glass.blur, EvGlassStyle.frost.blur]) {
      test('край полосы: размытие $blur продолжает стекло полосы и сходит на '
          'нет без ступенек', () {
        final s = EvScrollEdge.sigmas(blur);
        expect(s.length, greaterThanOrEqualTo(8));
        // У полосы — почти её размытие, а не треть, как было.
        expect(s.first, greaterThan(blur * .8));
        expect(s.last, lessThan(.5));
        for (var i = 1; i < s.length; i++) {
          expect(s[i], lessThan(s[i - 1]));
          // Соседние ступени отличаются не больше чем на пятую часть
          // размытия полосы — шов между ними не виден.
          expect(s[i - 1] - s[i], lessThan(blur * .22));
        }
      });
    }

    // Страница уходит под верхнюю полосу затем, чтобы стекло её размыло, —
    // об этом просил владелец. Сквозь иней навигационного слоя (заливка
    // 0.62, яркость 0.68) до глаза доходила четверть фона: обложки под
    // полосой были едва тёплым налётом, а подпись раздела не видна вовсе.
    testWidgets('сквозь верхнюю полосу доходит не меньше двух пятых фона', (
      tester,
    ) async {
      await _window(tester, 800, EvSpace.topBarHeight);
      final effects = _still(tester);
      final key = GlobalKey();

      /// Средняя яркость полосы там, где на ней ничего не написано.
      Future<double> over(Color backdrop) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildEvTheme(),
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            locale: const Locale('ru'),
            home: EvEffectsScope(
              effects: effects,
              child: RepaintBoundary(
                key: key,
                child: BackdropGroup(
                  child: Stack(
                    children: [
                      Positioned.fill(child: ColoredBox(color: backdrop)),
                      const Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        child: EvTopBar(section: ''),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await _settle(tester);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(key),
        );
        final bytes = await tester.runAsync(() async {
          final image = await boundary.toImage();
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          image.dispose();
          return data!;
        });
        var sum = 0;
        var n = 0;
        for (var y = 4; y < 12; y++) {
          for (var x = 300; x < 450; x++) {
            sum += bytes!.getUint8((y * 800 + x) * 4);
            n++;
          }
        }
        return sum / n;
      }

      final white = await over(const Color(0xFFFFFFFF));
      final black = await over(const Color(0xFF000000));
      // Заливка, блик и зерно в разнице гасятся: остаётся то, что стекло
      // пропускает от фона.
      expect((white - black) / 255, greaterThanOrEqualTo(.4));
    });

    testWidgets('край под верхней полосой размыт так же, как сама полоса', (
      tester,
    ) async {
      await _window(tester, 1440, 900);
      await tester.pumpWidget(_app(_still(tester)));
      await _settle(tester);

      final bar = tester.widget<EvGlass>(
        find
            .descendant(
              of: find.byType(EvTopBar),
              matching: find.byType(EvGlass),
            )
            .first,
      );
      final edge = tester
          .widgetList<EvScrollEdge>(find.byType(EvScrollEdge))
          .firstWhere((e) => e.fromTop);
      expect(edge.blur, bar.style.blur);
    });

    testWidgets('экран уходит под полосы, а не упирается в них', (
      tester,
    ) async {
      await _window(tester, 1440, 900);
      await tester.pumpWidget(_app(_still(tester)));
      await _settle(tester);

      final page = tester.getRect(find.byType(LibraryPage));
      expect(page.top, 0, reason: 'экран начинается под верхней полосой');
      expect(page.bottom, 900, reason: 'и продолжается под строкой подсказок');
      expect(page.left, EvSpace.railWidth);

      // …но содержимое начинается ниже полосы: её высота приходит
      // в отступах MediaQuery.
      final list = tester.widget<ListView>(find.byType(ListView).first);
      expect(list.padding, isA<EdgeInsets>());
      expect((list.padding! as EdgeInsets).top, EvSpace.topBarHeight);
      expect(tester.getRect(find.byType(EvHero)).top, greaterThanOrEqualTo(58));
    });

    testWidgets(
      'рейл и полосы стыкуются, как в прототипе: одна кромка на стык',
      (tester) async {
        await _window(tester, 1440, 900);
        await tester.pumpWidget(_app(_still(tester)));
        await _settle(tester);

        EvGlass glassOf(Type owner) => tester.widget<EvGlass>(
          find
              .descendant(
                of: find.byType(owner),
                matching: find.byType(EvGlass),
              )
              .first,
        );
        Rect rectOf(Type owner) => tester.getRect(
          find
              .descendant(
                of: find.byType(owner),
                matching: find.byType(EvGlass),
              )
              .first,
        );

        // Рейл — стекло во всю высоту у края окна, без отступа.
        expect(
          rectOf(EvRail),
          const Rect.fromLTWH(0, 0, EvSpace.railWidth, 900),
        );
        // Полосы начинаются ровно там, где кончается рейл.
        expect(rectOf(EvTopBar).left, EvSpace.railWidth);
        expect(rectOf(EvTopBar).top, 0);
        expect(rectOf(EvHintsBar).left, EvSpace.railWidth);
        expect(rectOf(EvHintsBar).bottom, 900);
        // Кромка светится только на стыке с экраном.
        expect(glassOf(EvRail).rim, {AxisDirection.right});
        expect(glassOf(EvTopBar).rim, {AxisDirection.down});
        expect(glassOf(EvHintsBar).rim, {AxisDirection.up});

        // Черта выбранного раздела — у самого края окна.
        final mark = find.descendant(
          of: find.byType(EvRailItem).first,
          matching: find.byType(AnimatedContainer),
        );
        expect(tester.getRect(mark.first).left, 0);
      },
    );
  });
}
