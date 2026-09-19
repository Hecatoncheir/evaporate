import 'package:evaporate/ui/widgets/hover_builder.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('наведение видно содержимому, а уход курсора его гасит', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: HoverBuilder(
            builder: (context, hovered, _) => SizedBox(
              width: 100,
              height: 100,
              child: Text(hovered ? 'над' : 'мимо'),
            ),
          ),
        ),
      ),
    );
    expect(find.text('мимо'), findsOneWidget);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(HoverBuilder)));
    await tester.pump();
    expect(find.text('над'), findsOneWidget);

    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(find.text('мимо'), findsOneWidget);
  });
}
