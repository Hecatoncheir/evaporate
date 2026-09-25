import 'package:evaporate/ui/widgets/decoration_clock.dart';
import 'package:evaporate/ui/widgets/pointer_trail.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Курсор над оболочкой — один на все украшения, которые за ним тянутся.
void main() {
  final probe = GlobalKey();

  Widget host({bool reduced = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: PointerTrailScope(
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 100, top: 50),
            child: SizedBox(key: probe, width: 200, height: 100),
          ),
        ),
      ),
    ),
  );

  PointerTrail trail() => PointerTrail.maybeOf(probe.currentContext!)!;

  bool clockRuns(WidgetTester tester) => (tester.state(
    find.byType(PointerTrailScope),
  ) as DecorationClock).isAnimating;

  Future<TestGesture> mouseAt(WidgetTester tester, Offset position) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(position);
    return mouse;
  }

  Future<void> frames(WidgetTester tester, [int count = 1]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('без мыши курсор стоит в покое, и часы не идут', (tester) async {
    await tester.pumpWidget(host());

    expect(trail().value, PointerTrail.rest);
    expect(trail().hasInput, isFalse);
    expect(clockRuns(tester), isFalse);
  });

  testWidgets('без оболочки курсора нет', (tester) async {
    await tester.pumpWidget(SizedBox(key: probe));

    expect(PointerTrail.maybeOf(probe.currentContext!), isNull);
  });

  // Сглаживание — ради украшений: волна, дёргающаяся за каждым рывком мыши,
  // читается как дрожь. Но и отставать навсегда нельзя.
  testWidgets('значение догоняет курсор сглаженно и останавливает часы', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    final mouse = await mouseAt(tester, const Offset(600, 450));
    addTearDown(mouse.removePointer);
    await frames(tester);

    expect(trail().hasInput, isTrue);
    expect(trail().target, const Offset(0.75, 0.75));
    expect(clockRuns(tester), isTrue);
    await frames(tester);
    final early = trail().value;
    expect(early.dx, greaterThan(PointerTrail.rest.dx));
    expect(early.dx, lessThan(0.75), reason: 'прыгнул, а не догнал');

    await frames(tester, 300);
    expect(trail().value, const Offset(0.75, 0.75));
    expect(
      clockRuns(tester),
      isFalse,
      reason: 'догнавшему курсору часы не нужны',
    );
  });

  // У касания нет ухода: взведи оно курсор, частицы и волна навсегда
  // остались бы у точки, где палец оторвали.
  testWidgets('касание пальцем курсором не считается', (tester) async {
    await tester.pumpWidget(host());
    final finger = await tester.startGesture(
      const Offset(600, 450),
      kind: PointerDeviceKind.touch,
    );
    await finger.moveTo(const Offset(650, 500));
    await finger.up();
    await frames(tester, 30);

    expect(trail().hasInput, isFalse);
    expect(trail().value, PointerTrail.rest);
  });

  testWidgets('ушедший курсор возвращается в покой', (tester) async {
    await tester.pumpWidget(host());
    final mouse = await mouseAt(tester, const Offset(600, 450));
    await frames(tester, 300);

    await mouse.removePointer();
    await frames(tester, 300);

    expect(trail().hasInput, isFalse);
    expect(trail().value, PointerTrail.rest);
  });

  testWidgets('при просьбе не двигаться курсор стоит', (tester) async {
    await tester.pumpWidget(host(reduced: true));
    final mouse = await mouseAt(tester, const Offset(600, 450));
    addTearDown(mouse.removePointer);
    await frames(tester, 30);

    expect(trail().value, PointerTrail.rest);
    expect(trail().hasInput, isFalse);
    expect(clockRuns(tester), isFalse);
  });

  // Украшения живут в своих коробках, а курсор — в долях всей оболочки:
  // перевод идёт через экран, поэтому переживает и сдвиг, и масштаб.
  testWidgets('доли оболочки переводятся в точки чужой коробки', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    final box = probe.currentContext!.findRenderObject()! as RenderBox;

    expect(
      trail().localIn(box, const Offset(0.5, 0.5)),
      const Offset(300, 250),
    );
    expect(trail().localIn(box, Offset.zero), const Offset(-100, -50));
  });
}
