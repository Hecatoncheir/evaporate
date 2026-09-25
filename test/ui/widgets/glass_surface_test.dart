import 'dart:ui';

import 'package:evaporate/ui/theme.dart';
import 'package:evaporate/ui/widgets/glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/host_widget.dart';

/// Стекло: что оно делает с подложкой и откуда берёт числа.
void main() {
  // Размытие, насыщенность и яркость — поля темы схемы, а не число в
  // виджете: ночное стекло гуще и темнее, дневное почти только размывает.
  testWidgets('стекло берёт фильтр своей схемы', (tester) async {
    final seen = <ImageFilter>[];
    for (final theme in [EvaporateTheme.dark(), EvaporateTheme.light()]) {
      await tester.pumpWidget(
        hostWidget(
          const GlassSurface(radius: 8, child: SizedBox.square(dimension: 40)),
          theme: theme,
        ),
      );
      await tester.pumpAndSettle();
      seen.add(
        tester.widget<BackdropFilter>(find.byType(BackdropFilter)).filter!,
      );
    }

    expect(seen.first, GlassSurface.filterOf(GlassSurfaceTheme.arclight));
    expect(seen.last, GlassSurface.filterOf(GlassSurfaceTheme.cartridge));
    expect(seen.first, isNot(seen.last), reason: 'схемы различаются стеклом');
  });

  // Матрица — как `saturate()` и `brightness()` в CSS: при единицах она
  // ничего не меняет, а серый цвет не окрашивает никакая насыщенность.
  test('без насыщенности и яркости стекло только размывает', () {
    const plain = GlassSurfaceTheme(
      fillOpacity: 0.6,
      opaqueFillOpacity: 0.9,
      sheenTopOpacity: null,
      sheenBottomOpacity: 0.6,
      rimOpacity: 0.1,
      counterLightOpacity: 0.1,
      backdropBlur: 10,
      backdropSaturation: 1,
      backdropBrightness: 1,
    );

    expect(
      GlassSurface.filterOf(plain),
      ImageFilter.compose(
        outer: const ColorFilter.matrix([
          1, 0, 0, 0, 0, //
          0, 1, 0, 0, 0, //
          0, 0, 1, 0, 0, //
          0, 0, 0, 1, 0,
        ]),
        inner: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      ),
    );
  });
  // Полосе у края панели кант нужен только на стыке с разделами: верх и
  // бока у неё — края самой панели, со своим кантом.
  testWidgets('кант стекла идёт только по названным краям', (tester) async {
    late BoxDecoration all, bottom;
    await tester.pumpWidget(
      hostWidget(
        Builder(
          builder: (context) {
            all = GlassSurface.decorationOf(context, radius: 0);
            bottom = GlassSurface.decorationOf(
              context,
              radius: 0,
              rim: const {AxisDirection.down},
            );
            return const SizedBox();
          },
        ),
      ),
    );

    final full = all.border! as Border;
    final seam = bottom.border! as Border;
    expect(full.isUniform, isTrue);
    expect(seam.bottom, full.bottom);
    expect([seam.top, seam.left, seam.right], everyElement(BorderSide.none));
  });
  // Смена схемы смешивает темы по кадрам. Ночного отлива нет, и он
  // смешивается с дневным как обычная заливка: у плотной полосы край на
  // первом же кадре проседал с 0.9 до 0.65 и просвечивал.
  testWidgets('плотная заливка не просвечивает посреди смены схемы', (
    tester,
  ) async {
    final dark = EvaporateTheme.dark();
    final light = EvaporateTheme.light();
    final tops = <double>[];
    // Тема — прямо `Theme`, а не темой приложения: та сама анимирует
    // переход и без хода времени так и стояла бы ночной.
    for (var step = 0; step <= 20; step++) {
      await tester.pumpWidget(
        Theme(
          data: ThemeData.lerp(dark, light, step / 20),
          child: Builder(
            builder: (context) {
              final fill = GlassSurface.decorationOf(
                context,
                radius: 0,
                opaque: true,
              );
              tops.add((fill.gradient! as LinearGradient).colors.first.a);
              return const SizedBox();
            },
          ),
        ),
      );
    }

    for (var i = 1; i < tops.length; i++) {
      expect(
        (tops[i] - tops[i - 1]).abs(),
        lessThan(0.05),
        reason: 'скачок между шагами ${i - 1} и $i: $tops',
      );
    }
  });
}
