import 'package:evaporate/ui/saves/sliver_side_by_side.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Две колонки из сливеров: рядом в широком окне, одна под другой — в
/// узком.
void main() {
  const left = Key('left');
  const right = Key('right');

  Widget columns({required bool wide}) => Directionality(
    textDirection: TextDirection.ltr,
    child: CustomScrollView(
      slivers: [
        SliverSideBySide(
          wide: wide,
          leftWidth: 300,
          gap: 20,
          left: const SliverToBoxAdapter(
            child: SizedBox(key: left, height: 100),
          ),
          right: SliverList.builder(
            itemCount: 1,
            itemBuilder: (_, _) => const SizedBox(key: right, height: 50),
          ),
        ),
      ],
    ),
  );

  testWidgets('в широком окне правая колонка встаёт рядом, за просветом', (
    tester,
  ) async {
    await tester.pumpWidget(columns(wide: true));

    expect(
      tester.getRect(find.byKey(left)),
      const Rect.fromLTWH(0, 0, 300, 100),
    );
    expect(
      tester.getRect(find.byKey(right)),
      const Rect.fromLTWH(320, 0, 480, 50),
    );
  });

  testWidgets('в узком окне колонки встают одна под другой во всю ширину', (
    tester,
  ) async {
    await tester.pumpWidget(columns(wide: false));

    expect(
      tester.getRect(find.byKey(left)),
      const Rect.fromLTWH(0, 0, 800, 100),
    );
    expect(
      tester.getRect(find.byKey(right)),
      const Rect.fromLTWH(0, 100, 800, 50),
    );
  });
}
