import 'package:evaporate/ui/saves/sliver_glass_clip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Обрезка и размытие стекла вокруг сливера.
void main() {
  final controller = ScrollController();
  tearDownAll(controller.dispose);

  Widget card() => Directionality(
    textDirection: TextDirection.ltr,
    child: CustomScrollView(
      controller: controller,
      slivers: const [
        SliverGlassClip(
          radius: 12,
          blur: 16,
          sliver: SliverToBoxAdapter(child: SizedBox(height: 1000)),
        ),
      ],
    ),
  );

  ClipRRectLayer clipOf(WidgetTester tester) =>
      tester.layers.whereType<ClipRRectLayer>().single;

  // Карта, уехавшая наполовину за край, скругляется там, где её настоящий
  // край, а не о край окна: иначе у прокрученной хронологии появлялись бы
  // скругления посреди строки.
  testWidgets('скругляется вся карта, а не её видимая часть', (tester) async {
    await tester.pumpWidget(card());

    expect(
      clipOf(tester).clipRRect!.outerRect,
      const Rect.fromLTWH(0, 0, 800, 1000),
    );
    expect(clipOf(tester).clipRRect!.tlRadius, const Radius.circular(12));

    controller.jumpTo(300);
    await tester.pump();

    expect(
      clipOf(tester).clipRRect!.outerRect,
      const Rect.fromLTWH(0, -300, 800, 1000),
    );
  });

  // Без размытия стекло сливером читалось бы иначе стекла-коробки рядом.
  testWidgets('подложка под картой размыта', (tester) async {
    await tester.pumpWidget(card());

    final backdrop = tester.layers.whereType<BackdropFilterLayer>().single;
    expect(backdrop.parent, same(clipOf(tester)));
  });
}
