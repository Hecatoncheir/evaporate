import 'package:evaporate/models/game.dart';
import 'package:evaporate/ui/ev/art/key_art.dart';
import 'package:evaporate/ui/ev/widgets/ev_effect_cover.dart';
import 'package:evaporate/ui/library/effects/cover_drops.dart';
import 'package:evaporate/ui/library/effects/foil/foil_card.dart';
import 'package:evaporate/ui/library/effects/portal/portal_sparks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/host_widget.dart';

/// Обложка карточки полки прототипа несёт украшения приложения: фольгу,
/// наклон, искры и капли — и зажигает их только у горящей карточки.
void main() {
  final game = Game(id: 'g', title: 'Игра', addedAt: DateTime(2026));

  Future<void> show(WidgetTester tester, {required bool active}) =>
      tester.pumpWidget(
        hostWidget(
          Center(
            child: SizedBox(
              width: 178,
              child: EvEffectCover(
                game: game,
                active: active,
                palette: EvCoverPalette.ash,
                seed: 7,
              ),
            ),
          ),
        ),
      );

  testWidgets('горящая карточка зажигает фольгу, искры и капли', (
    tester,
  ) async {
    await show(tester, active: true);

    expect(tester.widget<FoilCard>(find.byType(FoilCard)).active, isTrue);
    expect(
      tester.widget<PortalSparks>(find.byType(PortalSparks)).enabled,
      isTrue,
    );
    expect(tester.widget<CoverDrops>(find.byType(CoverDrops)).enabled, isTrue);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('погасшая карточка украшений не жжёт', (tester) async {
    await show(tester, active: false);

    expect(tester.widget<FoilCard>(find.byType(FoilCard)).active, isFalse);
    expect(
      tester.widget<PortalSparks>(find.byType(PortalSparks)).enabled,
      isFalse,
    );
    expect(tester.widget<CoverDrops>(find.byType(CoverDrops)).enabled, isFalse);
  });

  // Прототипу своя тема, а украшения берут цвета из расширений темы
  // приложения: без местной темы искры и ореол остались бы без облика.
  testWidgets('обложка не падает внутри чужой темы', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Center(
          child: SizedBox(
            width: 178,
            child: EvEffectCover(
              game: game,
              active: true,
              palette: EvCoverPalette.ash,
              seed: 7,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
