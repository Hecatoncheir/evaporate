import 'dart:io';
import 'dart:ui' as ui;

import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/ui/library/game_wave.dart';
import 'package:evaporate/ui/library/play_button.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:evaporate/ui/widgets/decorative_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  Future<void> frames(WidgetTester tester, int count) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 17));
    }
  }

  testWidgets(
    'play button activates once by keyboard and cannot activate when disabled',
    (tester) async {
      var taps = 0;
      var enabled = true;
      Future<void> show() => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PlayButton(
                label: 'Играть',
                effects: true,
                onPressed: enabled ? () => taps++ : null,
              ),
            ),
          ),
        ),
      );
      await show();
      await frames(tester, 30);
      final motion = tester.state<DecorativeMotionState>(
        find.byType(DecorativeMotion),
      );
      expect(motion.isAnimating, isTrue);
      final button = find.byType(FilledButton);
      Focus.of(tester.element(find.text('Играть'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, 1);
      enabled = false;
      await show();
      await tester.pumpAndSettle();
      expect(motion.isAnimating, isFalse);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.tap(button);
      await tester.pump();
      expect(taps, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'wave does not rebuild page content and respects lifecycle and reduced motion',
    (tester) async {
      var builds = 0;
      var reduced = false;
      var enabled = true;
      final content = Builder(
        builder: (_) {
          builds++;
          return const SizedBox.expand();
        },
      );
      Future<void> show() => tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: GameWave(enabled: enabled, child: content),
          ),
        ),
      );
      await show();
      await frames(tester, 90);
      final motion = tester.state<DecorativeMotionState>(
        find.byType(DecorativeMotion),
      );
      expect(motion.time, greaterThan(1));
      expect(builds, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await frames(tester, 2);
      expect(motion.isAnimating, isFalse);
      final paused = motion.time;
      await frames(tester, 10);
      expect(motion.time, paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await frames(tester, 2);
      expect(motion.isAnimating, isTrue);
      reduced = true;
      await show();
      await tester.pumpAndSettle();
      expect(motion.isAnimating, isFalse);
      expect(motion.time, 0);
      reduced = false;
      enabled = false;
      await show();
      await tester.pumpAndSettle();
      expect(motion.isAnimating, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );

  late Directory tmp;
  setUp(() async => tmp = await TestHarness.makeTempDir());
  tearDown(() => TestHarness.removeTempDir(tmp));

  testWidgets('game page preview and hidden-page animation pause', (
    tester,
  ) async {
    final preview = Platform.environment['GAME_PAGE_PREVIEW'];
    if (preview != null) {
      for (final entry in {
        'Ahem': 'assets/fonts/NunitoSans.ttf',
        'Nunito': 'assets/fonts/Nunito.ttf',
        'Nunito Sans': 'assets/fonts/NunitoSans.ttf',
        'JetBrains Mono': 'assets/fonts/JetBrainsMono.ttf',
        'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      }.entries) {
        await (FontLoader(
          entry.key,
        )..addFont(rootBundle.load(entry.value))).load();
      }
    }
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    harness.library.add(
      const GameAdded(
        id: 'wave-demo',
        title: 'Celeste',
        status: GameStatus.installed,
        executablePath: '/not-launched/demo',
      ),
    );
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      harness.buildApp(
        theme: Platform.environment['GAME_PAGE_LIGHT'] == '1'
            ? EvaporateTheme.light()
            : EvaporateTheme.dark(),
        motion: true,
        builder: (_, child) => RepaintBoundary(key: boundary, child: child),
      ),
    );
    await frames(tester, 30);
    harness.nav.add(const GameOpened('wave-demo'));
    await frames(tester, 180);
    expect(find.byType(PlayButton), findsOneWidget);
    final motions = tester
        .stateList<DecorativeMotionState>(find.byType(DecorativeMotion))
        .toList();
    expect(motions.length, 2);
    expect(motions.every((s) => s.isAnimating), isTrue);
    if (preview != null) {
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(preview).writeAsBytes(bytes!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
    }
    harness.nav.add(const SectionSelected(3));
    await frames(tester, 20);
    expect(motions.every((s) => !s.isAnimating), isTrue);
    harness.nav.add(const SectionSelected(0));
    await frames(tester, 20);
    expect(motions.every((s) => s.isAnimating), isTrue);
    harness.settings.add(
      SettingsChanged(harness.settings.state.copyWith(libraryEffects: false)),
    );
    await tester.pumpAndSettle();
    expect(motions.every((s) => !s.isAnimating), isTrue);
    expect(tester.takeException(), isNull);
  });
}
