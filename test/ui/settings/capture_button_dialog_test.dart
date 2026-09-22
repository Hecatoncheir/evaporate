import 'package:evaporate/input/gamepad_service.dart';
import 'package:evaporate/input/nav_action.dart';
import 'package:evaporate/ui/settings/capture_button_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamepads/gamepads.dart';

import '../../support/host_widget.dart';
import '../../support/test_app.dart';

/// Окно захвата кнопки закрывается и с самого геймпада.
///
/// Прежде любая кнопка становилась назначением, и человек с одним
/// геймпадом в руках из окна выйти не мог: «Отмена» нажималась только
/// мышью.
void main() {
  late GamepadService gamepad;
  setUp(() => gamepad = GamepadService());
  tearDown(() => gamepad.dispose());

  Future<List<GamepadButton?>> capture(
    WidgetTester tester,
    GamepadButton pressed,
  ) async {
    final results = <GamepadButton?>[];
    await tester.pumpWidget(
      hostWidget(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await showDialog<GamepadButton>(
                context: context,
                builder: (_) => CaptureButtonDialog(
                  action: NavAction.search,
                  gamepad: gamepad,
                ),
              ),
            ),
            child: const Text('назначить'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('назначить'));
    await tester.pumpAndSettle();
    expect(find.byType(CaptureButtonDialog), findsOneWidget);

    gamepad.handleEvent(buttonEvent(pressed, 1));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('Start закрывает окно, ничего не назначая', (tester) async {
    final results = await capture(
      tester,
      CaptureButtonDialogState.cancelButton,
    );

    expect(find.byType(CaptureButtonDialog), findsNothing);
    expect(results, [null]);
  });

  testWidgets('другая кнопка становится назначением', (tester) async {
    final results = await capture(tester, GamepadButton.y);

    expect(results, [GamepadButton.y]);
  });
}
