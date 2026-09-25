import 'dart:io';

import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/ui/ev/shell/ev_top_bar.dart';
import 'package:evaporate/ui/ev/widgets/ev_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamepads/gamepads.dart';

import '../../support/test_app.dart';

/// Закрыть приложение с геймпада было нечем: своя панель окна даёт крестик
/// мышью, значок в трее — пункт меню, а стрелками до них не дойти.
void main() {
  // Ищем по ключу перевода, а не по строке: правка формулировки в
  // ARB иначе роняет тест, ничего не сломав в приложении.
  final l = LRu();

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

  testWidgets('кнопка выхода есть в верхней панели и закрывает окно', (
    tester,
  ) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.buildApp());
    await frames(tester);

    final quit = find.byKey(const ValueKey('rail-quit'));
    expect(quit, findsOneWidget);
    expect(find.byTooltip(l.quitApp), findsOneWidget);

    await tester.tap(quit);
    await frames(tester);

    // Именно close, а не destroy: закрытие перехвачено, и по этому пути
    // отложенные записи успевают лечь на диск.
    expect(calls, contains('close'));
  });

  // Кнопка остаётся доступной с геймпада: от клавиш обоймы — вверх до её
  // верха, оттуда в верхнюю рейку и по ней вправо.
  testWidgets('до кнопки выхода можно дойти геймпадом', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.buildApp());
    await frames(tester);

    final quit = find.byKey(const ValueKey('rail-quit'));
    Focus.of(
      tester.element(
        find.descendant(
          of: find.byKey(const ValueKey('rail-settings')),
          matching: find.byType(EvIcon),
        ),
      ),
    ).requestFocus();
    await frames(tester);

    bool focusedIn(Finder area) {
      final context = primaryFocus?.context;
      return context != null &&
          find
              .descendant(of: area, matching: find.byWidget(context.widget))
              .evaluate()
              .isNotEmpty;
    }

    for (var step = 0; step < 6 && !focusedIn(find.byType(EvTopBar)); step++) {
      await harness.tapButton(tester, GamepadButton.dpadUp);
    }
    expect(
      focusedIn(find.byType(EvTopBar)),
      isTrue,
      reason: 'вверх от обоймы в верхнюю рейку не выйти',
    );
    for (var step = 0; step < 8 && !focusedIn(quit); step++) {
      await harness.tapButton(tester, GamepadButton.dpadRight);
    }

    expect(
      focusedIn(quit),
      isTrue,
      reason: 'стрелками до кнопки выхода не добраться',
    );
  });
}
