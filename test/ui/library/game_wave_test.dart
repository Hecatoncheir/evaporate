import 'package:evaporate/ui/library/effects/game_wave.dart';
import 'package:evaporate/ui/widgets/pointer_trail.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Вздутие волны тянется за курсором оболочки. Сглаживание живёт у
/// курсора (`PointerTrail`), а не в художнике: тот создаётся заново при
/// каждой пересборке того, что под ним нарисовано.
void main() {
  Future<void> frames(WidgetTester tester, [int count = 40]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 17));
    }
  }

  Widget host({required String label, required VoidCallback onPressed}) =>
      MaterialApp(
        home: PointerTrailScope(
          child: Center(
            child: SizedBox(
              width: 400,
              height: 300,
              child: GameWave(
                enabled: true,
                child: Center(
                  child: TextButton(onPressed: onPressed, child: Text(label)),
                ),
              ),
            ),
          ),
        ),
      );

  GameWaveState wave(WidgetTester tester) =>
      tester.state<GameWaveState>(find.byType(GameWave));

  // Курсор оболочки — в долях всего окна, а вздутие встаёт там, где он над
  // волной: в правом нижнем углу волны это почти единица по обеим осям, а
  // в долях окна 800×600 было бы 0,73 и 0,72.
  testWidgets('курсор оболочки доходит до волны в её долях', (tester) async {
    await tester.pumpWidget(host(label: 'первая', onPressed: () {}));
    await frames(tester);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(
      tester.getTopLeft(find.byType(GameWave)) + const Offset(380, 280),
    );
    await frames(tester, 120);

    expect(wave(tester).pointer.value.dx, closeTo(0.95, 0.02));
    expect(wave(tester).pointer.value.dy, closeTo(0.93, 0.02));
  });

  testWidgets('сглаженный курсор переживает пересборку содержимого', (
    tester,
  ) async {
    var label = 'первая';
    late StateSetter rebuild;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return host(label: label, onPressed: () {});
        },
      ),
    );
    await frames(tester);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(
      tester.getTopLeft(find.byType(GameWave)) + const Offset(380, 280),
    );
    await frames(tester);

    final followed = wave(tester).pointer.value;
    expect(
      followed.dx,
      greaterThan(0.7),
      reason: 'волна не потянулась за курсором — проверять дальше нечего',
    );

    // Ровно то, что делает библиотека при переводе выделения с игры на игру:
    // пересобирает то, что нарисовано под волной.
    rebuild(() => label = 'вторая');
    await tester.pump(const Duration(milliseconds: 17));

    expect(find.text('вторая'), findsOneWidget);
    expect(
      wave(tester).pointer.value.dx,
      greaterThan(followed.dx - 0.05),
      reason: 'вздутие волны прыгнуло к середине, хотя мышь не двигалась',
    );
  });

  // Выключенная волна тоже знает, где курсор: включат её — вздутие сразу
  // стоит там, а не прыгает туда из середины с первым движением мыши.
  testWidgets('включённая волна встаёт за курсором без рывка', (tester) async {
    var enabled = false;
    late StateSetter rebuild;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return MaterialApp(
            home: PointerTrailScope(
              child: Center(
                child: SizedBox(
                  width: 400,
                  height: 300,
                  child: GameWave(
                    enabled: enabled,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(
      tester.getTopLeft(find.byType(GameWave)) + const Offset(380, 280),
    );
    await frames(tester, 120);

    rebuild(() => enabled = true);
    await tester.pump(const Duration(milliseconds: 17));

    expect(wave(tester).pointer.value.dx, closeTo(0.95, 0.02));
  });

  testWidgets('без оболочки волна стоит посередине', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GameWave(enabled: true, child: SizedBox.expand()),
      ),
    );
    await frames(tester, 5);

    expect(wave(tester).pointer.value, const Offset(0.5, 0.5));
    await tester.pumpWidget(const SizedBox());
  });
}
