import 'dart:async';
import 'dart:io';

import 'package:evaporate/bloc/downloads/downloads_bloc.dart';
import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/input/gamepad_binding.dart';
import 'package:evaporate/input/nav_action.dart';
import 'package:evaporate/models/app_section.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/services/launch/game_launcher.dart';
import 'package:evaporate/ui/ev/app/ev_gamepad_primary_action.dart';
import 'package:evaporate/ui/ev/widgets/ev_play_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamepads/gamepads.dart';

import '../../../support/test_app.dart';

class _Launcher extends GameLauncher {
  final launches = <String>[];
  final stops = <String>[];

  @override
  Future<void> terminate(String gameId) async => stops.add(gameId);

  @override
  Future<void> launch(
    Game game, {
    required void Function(Game, Duration, int) onExit,
  }) async => launches.add(game.id);
}

class _Events extends BlocObserver {
  final events = <Object?>[];
  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    events.add(event);
    super.onEvent(bloc, event);
  }
}

void main() {
  late Directory tmp;
  late _Launcher launcher;
  setUp(() async {
    tmp = await TestHarness.makeTempDir();
    launcher = _Launcher();
  });
  tearDown(() => TestHarness.removeTempDir(tmp));

  Future<TestHarness> show(
    WidgetTester tester, {
    GameStatus status = GameStatus.installed,
  }) async {
    final harness = TestHarness(tmp, launcher: launcher);
    addTearDown(harness.dispose);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final id in ['alpha', 'beta']) {
      harness.library.add(
        GameAdded(id: id, title: id, executablePath: '$id.exe', status: status),
      );
    }
    await harness.pump(tester);
    harness.nav.add(const GameSelected('alpha'));
    await tester.pumpAndSettle();
    return harness;
  }

  Future<void> button(
    WidgetTester tester,
    TestHarness harness,
    GamepadButton button,
    double value,
  ) async {
    harness.gamepad.handleEvent(buttonEvent(button, value));
    await tester.pump();
    await tester.pump();
    if (value == 0) {
      // После успешного запуска библиотека сохраняет состояние через 400 мс.
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  for (final status in [
    GameStatus.running,
    GameStatus.downloading,
    GameStatus.paused,
  ]) {
    testWidgets('главное действие для ${status.name} срабатывает сразу', (
      tester,
    ) async {
      final previous = Bloc.observer;
      final observer = _Events();
      Bloc.observer = observer;
      addTearDown(() => Bloc.observer = previous);
      final harness = await show(tester, status: status);
      await button(tester, harness, GamepadButton.x, 1);
      final actions = observer.events
          .where(
            (event) =>
                event is GameStopRequested ||
                event is DownloadPauseRequested ||
                event is DownloadResumeRequested,
          )
          .toList();
      expect(actions, hasLength(1));
      expect(actions.single, switch (status) {
        GameStatus.running => isA<GameStopRequested>(),
        GameStatus.downloading => isA<DownloadPauseRequested>(),
        _ => isA<DownloadResumeRequested>(),
      });
      expect(find.byKey(const ValueKey('gamepad-launch-charge')), findsNothing);
      expect(launcher.launches, isEmpty);
      await button(tester, harness, GamepadButton.x, 0);
    });
  }

  testWidgets('X запускает ровно один раз после 620 мс даже без анимаций', (
    tester,
  ) async {
    final harness = await show(tester);
    await button(tester, harness, GamepadButton.x, 1);
    await tester.pump(const Duration(milliseconds: 300));
    final charge = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('gamepad-launch-charge')),
    );
    expect(charge.value, closeTo(300 / 620, .02));
    await button(tester, harness, GamepadButton.x, 1);
    await tester.pump(const Duration(milliseconds: 319));
    expect(launcher.launches, isEmpty);
    await tester.pump(const Duration(milliseconds: 2));
    await tester.pump();
    expect(launcher.launches, ['alpha']);
    await tester.pump(const Duration(seconds: 1));
    expect(launcher.launches, ['alpha']);
    await button(tester, harness, GamepadButton.x, 0);
  });

  for (final modifier in [
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.metaLeft,
  ]) {
    testWidgets(
      '${modifier.keyLabel}+Enter отменяет короткое нажатие и не повторяет запуск',
      (tester) async {
        await show(tester);
        await tester.sendKeyDownEvent(modifier);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(modifier);
        await tester.pump(const Duration(seconds: 1));
        expect(launcher.launches, isEmpty);
        await tester.sendKeyDownEvent(modifier);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
        await tester.pump(const Duration(milliseconds: 319));
        expect(launcher.launches, isEmpty);
        await tester.pump(const Duration(milliseconds: 2));
        await tester.pump();
        expect(launcher.launches, ['alpha']);
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
        await tester.pump(const Duration(seconds: 1));
        expect(launcher.launches, ['alpha']);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(modifier);
        await tester.pump(const Duration(milliseconds: 500));
      },
    );
  }

  testWidgets('короткое X отменяется, следующее удержание начинается заново', (
    tester,
  ) async {
    final harness = await show(tester);
    await button(tester, harness, GamepadButton.x, 1);
    await tester.pump(const Duration(milliseconds: 400));
    await button(tester, harness, GamepadButton.x, 0);
    expect(find.byKey(const ValueKey('gamepad-launch-charge')), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(launcher.launches, isEmpty);
    await button(tester, harness, GamepadButton.x, 1);
    await tester.pump(const Duration(milliseconds: 619));
    expect(launcher.launches, isEmpty);
    await tester.pump(const Duration(milliseconds: 2));
    await tester.pump();
    expect(launcher.launches, ['alpha']);
    await button(tester, harness, GamepadButton.x, 0);
  });

  for (final change in [
    'selection',
    'executable',
    'section',
    'binding',
    'disabled',
    'capture',
    'lifecycle',
  ]) {
    testWidgets('удержание отменяется при $change', (tester) async {
      final harness = await show(tester);
      await button(tester, harness, GamepadButton.x, 1);
      await tester.pump(const Duration(milliseconds: 300));
      switch (change) {
        case 'selection':
          harness.nav.add(const GameSelected('beta'));
        case 'executable':
          harness.library.add(const GameExecutableSet('alpha', 'other.exe'));
        case 'section':
          harness.nav.add(const SectionSelected(AppSection.settings));
        case 'binding':
          harness.gamepad.binding = const GamepadBinding().assign(
            GamepadButton.y,
            NavAction.primaryAction,
          );
        case 'disabled':
          harness.gamepad.binding = harness.gamepad.binding.copyWith(
            enabled: false,
          );
        case 'capture':
          harness.gamepad.capturing = true;
        case 'lifecycle':
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
      }
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(launcher.launches, isEmpty);
      expect(find.byKey(const ValueKey('gamepad-launch-charge')), findsNothing);
      await button(tester, harness, GamepadButton.x, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
  }

  testWidgets('переназначенная Y удерживает главное действие', (tester) async {
    final harness = await show(tester);
    harness.gamepad.binding = const GamepadBinding().assign(
      GamepadButton.y,
      NavAction.primaryAction,
    );
    await button(tester, harness, GamepadButton.y, 1);
    await tester.pump(const Duration(milliseconds: 621));
    await tester.pump();
    expect(launcher.launches, ['alpha']);
    await button(tester, harness, GamepadButton.y, 0);
  });

  testWidgets('диалог, открытый во время удержания, предотвращает запуск', (
    tester,
  ) async {
    final harness = await show(tester);
    await button(tester, harness, GamepadButton.x, 1);
    await tester.pump(const Duration(milliseconds: 300));
    unawaited(
      showDialog<void>(
        context: tester.element(find.byType(EvGamepadPrimaryAction)),
        builder: (_) => const AlertDialog(content: Text('dialog')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(launcher.launches, isEmpty);
    await button(tester, harness, GamepadButton.x, 0);
  });

  testWidgets(
    'A на кнопке запуска требует удержания и отменяется отпусканием',
    (tester) async {
      final harness = await show(tester);
      final play = find.byType(EvPlayButton);
      final focus = tester
          .widget<FocusableActionDetector>(
            find.descendant(
              of: play,
              matching: find.byType(FocusableActionDetector),
            ),
          )
          .focusNode!;
      focus.requestFocus();
      await tester.pumpAndSettle();
      await button(tester, harness, GamepadButton.a, 1);
      await tester.pump(const Duration(milliseconds: 300));
      harness.gamepad.handleEvent(buttonEvent(GamepadButton.a, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 17));
      expect(launcher.launches, isEmpty);
      await button(tester, harness, GamepadButton.a, 1);
      await tester.pump(const Duration(milliseconds: 619));
      expect(launcher.launches, isEmpty);
      await tester.pump(const Duration(milliseconds: 2));
      await tester.pump();
      expect(launcher.launches, ['alpha']);
      await button(tester, harness, GamepadButton.a, 0);
    },
  );
}
