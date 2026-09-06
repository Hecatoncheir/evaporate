import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamepads/gamepads.dart';

import 'support/test_app.dart';

/// Закрыть приложение с геймпада было нечем: своя панель окна даёт крестик
/// мышью, значок в трее — пункт меню, а стрелками до них не дойти.
void main() {
  late Directory tmp;
  const channel = MethodChannel('window_manager');
  late List<String> calls;

  setUp(() async {
    tmp = await TestHarness.makeTempDir();
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await TestHarness.removeTempDir(tmp);
  });

  Future<void> frames(WidgetTester tester, [int count = 12]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 17));
    }
  }

  testWidgets('кнопка выхода есть в боковой панели и закрывает окно', (
    tester,
  ) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.buildApp());
    await frames(tester);

    final quit = find.byKey(const ValueKey('rail-quit'));
    expect(quit, findsOneWidget);
    expect(find.text('Выключить'), findsOneWidget);

    await tester.tap(quit);
    await frames(tester);

    // Именно close, а не destroy: закрытие перехвачено, и по этому пути
    // отложенные записи успевают лечь на диск.
    expect(calls, contains('close'));
  });

  // Кнопка нужна была ровно затем, чтобы до неё доходили стрелки.
  testWidgets('до кнопки выхода можно дойти геймпадом', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.buildApp());
    await frames(tester);

    final quit = find.byKey(const ValueKey('rail-quit'));
    Focus.of(tester.element(find.text('Настройки').first)).requestFocus();
    await frames(tester);

    var reached = false;
    for (var step = 0; step < 12 && !reached; step++) {
      await harness.tapButton(tester, GamepadButton.dpadDown);
      final context = primaryFocus?.context;
      reached =
          context != null &&
          find
              .descendant(of: quit, matching: find.byWidget(context.widget))
              .evaluate()
              .isNotEmpty;
    }

    expect(reached, isTrue, reason: 'стрелками до кнопки выхода не добраться');
  });
}
