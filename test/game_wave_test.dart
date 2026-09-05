import 'package:evaporate/ui/library/game_wave.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Волна тянется за указателем сглаженно, и это сглаживание — состояние.
/// Держать его в рисовальщике нельзя: рисовальщик создаётся заново при
/// каждой пересборке того, что под ним нарисовано.
void main() {
  Future<void> frames(WidgetTester tester, [int count = 40]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 17));
    }
  }

  testWidgets('сглаженный указатель переживает пересборку содержимого', (
    tester,
  ) async {
    final trail = WaveTrail();
    var label = 'первая';

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Center(
            child: SizedBox(
              width: 400,
              height: 300,
              child: GameWave(
                enabled: true,
                trail: trail,
                child: Center(
                  child: TextButton(
                    onPressed: () => setState(() => label = 'вторая'),
                    child: Text(label),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await frames(tester);

    // Уводим указатель в дальний угол и даём волне за ним потянуться.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(
      tester.getTopLeft(find.byType(GameWave)) + const Offset(380, 280),
    );
    await frames(tester);

    expect(
      trail.smoothed.dx,
      greaterThan(0.7),
      reason: 'волна не потянулась за указателем — проверять дальше нечего',
    );
    final followed = trail.smoothed;

    // Ровно то, что делает библиотека при переводе выделения с игры на игру:
    // пересобирает то, что нарисовано под волной.
    await tester.tap(find.text('первая'));
    await tester.pump(const Duration(milliseconds: 17));

    expect(find.text('вторая'), findsOneWidget);
    expect(
      trail.smoothed.dx,
      greaterThan(followed.dx - 0.05),
      reason: 'вздутие волны прыгнуло к середине, хотя мышь не двигалась',
    );
  });
}
