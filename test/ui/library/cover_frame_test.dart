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
}
