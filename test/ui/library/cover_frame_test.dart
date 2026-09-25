import 'package:evaporate/models/game.dart';
import 'package:evaporate/ui/library/cover/cover_frame.dart';
import 'package:evaporate/ui/library/effects/portal/portal_outline.dart';
import 'package:evaporate/ui/library/effects/portal/portal_sparks.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/host_widget.dart';

/// Корпус плитки: вырез обложки, искры и тень.
void main() {
  final game = Game(id: 'g', title: 'Игра', addedAt: DateTime(2026));

  Future<void> show(WidgetTester tester, {required bool selected}) =>
      tester.pumpWidget(
        hostWidget(
          Center(
            child: SizedBox(
              width: 120,
              child: CoverFrame(
                game: game,
                task: null,
                selected: selected,
                dropsEnabled: false,
                portalEnabled: true,
              ),
            ),
          ),
        ),
      );

  // Искры рождаются на кромке со скруглением `PortalOutline.corner`, а
  // обложка режется своим углом. Прежде вырез был мельче кромки, и в углу
  // между обложкой и искрами оставался тёмный шов.
  testWidgets('вырез обложки совпадает с кромкой искр', (tester) async {
    await show(tester, selected: true);

    final clip = tester.widget<ClipRRect>(
      find.descendant(
        of: find.byType(CoverFrame),
        matching: find.byType(ClipRRect),
      ),
    );
    expect(clip.borderRadius, BorderRadius.circular(PortalOutline.corner));
    expect(EvaporateTheme.radiusPanel, PortalOutline.corner);
  });

  testWidgets('искры горят только у выбранной обложки', (tester) async {
    await show(tester, selected: false);
    expect(
      tester.widget<PortalSparks>(find.byType(PortalSparks)).enabled,
      isFalse,
    );

    await show(tester, selected: true);
    expect(
      tester.widget<PortalSparks>(find.byType(PortalSparks)).enabled,
      isTrue,
    );

    await tester.pumpWidget(const SizedBox());
  });

  /// Украшение, которое лежит прямо над искрами, — ореол.
  BoxDecoration glowOf(WidgetTester tester) =>
      tester
              .widget<DecoratedBox>(
                find
                    .ancestor(
                      of: find.byType(PortalSparks),
                      matching: find.byType(DecoratedBox),
                    )
                    .first,
              )
              .decoration
          as BoxDecoration;

  testWidgets('выбранная плитка светится, невыбранная нет', (tester) async {
    await show(tester, selected: false);
    expect(glowOf(tester).boxShadow, isEmpty);

    await show(tester, selected: true);
    final context = tester.element(find.byType(CoverFrame));
    final [glow] = glowOf(tester).boxShadow!;
    final tone = context.colors.glow;
    expect(glow.color, tone.withValues(alpha: tone.a * EvaporateAlpha.ghost));
    expect(glow.blurRadius, HardwareSurfaceTheme.of(context).tileGlowBlur);

    await tester.pumpWidget(const SizedBox());
  });

  // Искры рисуются первым слоем под обложкой: ореол рядом с тенью, внутри
  // искр, лёг бы поверх них и погасил самые яркие у кромки.
  testWidgets('ореол лежит снаружи искр, а не внутри', (tester) async {
    await show(tester, selected: true);
    final glow = tester.element(find.byType(CoverFrame)).colors.glow;

    final inside = tester.widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(PortalSparks),
        matching: find.byType(DecoratedBox),
      ),
    );
    for (final box in inside) {
      final shadows = (box.decoration as BoxDecoration?)?.boxShadow ?? [];
      expect(
        shadows.where((s) => s.color.b == glow.b && s.color.r == glow.r),
        isEmpty,
      );
    }

    await tester.pumpWidget(const SizedBox());
  });
}
