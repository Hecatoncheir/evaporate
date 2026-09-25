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
}
