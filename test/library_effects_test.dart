import 'dart:io';
import 'dart:ui' as ui;

import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/models/app_settings.dart';
import 'package:evaporate/ui/library/game_cover.dart';
import 'package:evaporate/ui/library/library_atmosphere.dart';
import 'package:evaporate/ui/library/liquid_focus.dart';
import 'package:evaporate/ui/library/liquid_card.dart';
import 'package:evaporate/ui/library/particle_field.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ambient points use the exact requested colors', () {
    expect(ambientParticleColor(false), const Color(0xFF2F0346));
    expect(ambientParticleColor(true), const Color(0xFFE6DBC7));
  });

  test('selection changes the actual card silhouette', () {
    const size = Size(200, 300);
    final normal = const LiquidCardClipper(0).getClip(size);
    final selected = const LiquidCardClipper(1).getClip(size);
    expect(normal.contains(const Offset(10, 10)), isTrue);
    expect(selected.contains(const Offset(10, 10)), isFalse);
    expect(selected.contains(size.center(Offset.zero)), isTrue);
  });

  group('particle simulation', () {
    test('density grows near attraction without changing particle size', () {
      final field = ParticleField()..resize(const Size(1000, 700));
      expect(field.particles.length, ParticleField.ambientCount);
      field.card = const Rect.fromLTWH(320, 150, 180, 270);
      for (var i = 0; i < 360; i++) {
        field.step(1 / 60);
      }
      expect(
        field.particles.length,
        greaterThan(ParticleField.ambientCount + 60),
      );
      expect(field.particles.length, lessThanOrEqualTo(ParticleField.maxCount));
      final close = field.particles.where(
        (p) => field.proximity(p.position) > 0.7,
      );
      expect(close.length, greaterThan(80));
      expect(
        field.particles.where((p) => field.proximity(p.position) == 0).length,
        greaterThan(60),
      );
      expect(InkParticle.radius, 1.25);
      expect(field.proximity(const Offset(320, 200)), 1);
      expect(field.proximity(const Offset(950, 600)), 0);
      expect(close.any((p) => p.glow > 0.8), isTrue);
    });

    test('pointer attracts and extra particles expire after leaving', () {
      final field = ParticleField()..resize(const Size(600, 400));
      field.pointer = const Offset(300, 200);
      for (var i = 0; i < 300; i++) {
        field.step(1 / 60);
      }
      expect(field.particles.length, greaterThan(ParticleField.ambientCount));
      field.pointer = null;
      for (var i = 0; i < 240; i++) {
        field.step(1 / 60);
      }
      expect(field.particles.length, ParticleField.ambientCount);
    });

    test('inside a card particles target its perimeter, not the centre', () {
      const rect = Rect.fromLTWH(10, 10, 100, 180);
      expect(
        ParticleField.edgePoint(rect, const Offset(55, 80)),
        const Offset(10, 80),
      );
      expect(
        ParticleField.edgePoint(rect, const Offset(105, 80)),
        const Offset(110, 80),
      );
      expect(
        ParticleField.edgePoint(rect, const Offset(55, 12)),
        const Offset(55, 10),
      );
      expect(
        ParticleField.edgePoint(rect, const Offset(55, 185)),
        const Offset(55, 190),
      );
      expect(ParticleField.edgePoint(rect, Offset.zero), const Offset(10, 10));
    });

    test(
      'long sessions, resize, zero size and resumed frames stay bounded',
      () {
        final field = ParticleField();
        field.step(1);
        field.resize(Size.zero);
        expect(field.particles, isEmpty);
        field.resize(const Size(400, 300));
        field.pointer = const Offset(200, 100);
        for (var i = 0; i < 2400; i++) {
          field.step(1 / 60);
        }
        field.resize(const Size(100, 100));
        final time = field.time;
        field.step(double.nan);
        field.step(-1);
        expect(field.time, time);
        field.step(1000);
        expect(field.time - time, closeTo(1 / 30, 1e-8));
        expect(
          field.particles.length,
          lessThanOrEqualTo(ParticleField.maxCount),
        );
        for (final particle in field.particles) {
          expect(particle.position.dx.isFinite, isTrue);
          expect(particle.position.dy.isFinite, isTrue);
          expect(particle.velocity.distance, lessThanOrEqualTo(180.001));
        }
      },
    );
  });

  test('liquid focus retargets continuously, tracks scrolling and clears', () {
    final focus = LiquidFocus();
    const a = Rect.fromLTWH(20, 20, 180, 270);
    const b = Rect.fromLTWH(230, 20, 180, 270);
    focus.update(a, 'a');
    expect(focus.progress, 1);
    focus.update(b, 'b');
    expect(focus.progress, 0);
    for (var i = 0; i < 12; i++) {
      focus.step(1 / 60);
    }
    expect(focus.current!.width.isFinite, isTrue);
    final intermediate = focus.current;
    focus.update(a, 'a');
    expect(focus.from, intermediate);
    focus.step(1 / 60);
    final progress = focus.progress;
    focus.update(a.translate(0, -15), 'a');
    expect(focus.progress, progress);
    for (var i = 0; i < 60; i++) {
      focus.step(1 / 60);
    }
    expect(focus.progress, 1);
    expect(focus.current, a.translate(0, -15));
    focus.update(null, null);
    expect(focus.current, isNull);
    expect(focus.target, isNull);
  });

  test(
    'effects preference defaults on, round-trips and participates in equality',
    () {
      final settings = AppSettings.fromJson({}, '/games');
      expect(settings.libraryEffects, isTrue);
      final disabled = settings.copyWith(libraryEffects: false);
      expect(disabled, isNot(settings));
      expect(
        AppSettings.fromJson(disabled.toJson(), '/games').toJson(),
        disabled.toJson(),
      );
    },
  );

  group('live library', () {
    late Directory tmp;
    setUp(() async => tmp = await TestHarness.makeTempDir());
    tearDown(() => TestHarness.removeTempDir(tmp));

    Future<void> frames(WidgetTester tester, int count) async {
      for (var i = 0; i < count; i++) {
        await tester.pump(const Duration(milliseconds: 17));
      }
    }

    Future<TestHarness> app(
      WidgetTester tester, {
      TransitionBuilder? builder,
    }) async {
      final harness = TestHarness(tmp);
      addTearDown(harness.dispose);
      for (final title in [
        'HADES',
        'ORI',
        'CELESTE',
        'CONTROL',
        'HOLLOW KNIGHT',
        'STRAY',
        'TUNIC',
        'DEAD CELLS',
        'INSIDE',
        'JOURNEY',
        'PORTAL',
        'ABZU',
      ]) {
        harness.addGame(title: title);
      }
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        harness.buildApp(
          theme: EvaporateTheme.light(),
          motion: true,
          builder: builder,
        ),
      );
      await frames(tester, 40);
      return harness;
    }

    testWidgets('simulation repaints without rebuilding its content', (
      tester,
    ) async {
      var builds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: LibraryAtmosphere(
            enabled: true,
            targetKey: () => null,
            child: Builder(
              builder: (_) {
                builds++;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      await frames(tester, 90);
      expect(builds, 1);
      final state = tester.state<LibraryAtmosphereState>(
        find.byType(LibraryAtmosphere),
      );
      expect(state.field.time, greaterThan(1));
      expect(state.field.particles.length, ParticleField.ambientCount);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      'hover, keyboard focus, resize, and scroll track visible card bounds',
      (tester) async {
        final harness = await app(tester);
        final state = tester.state<LibraryAtmosphereState>(
          find.byType(LibraryAtmosphere),
        );
        expect(state.isAnimating, isTrue);
        expect(state.focus.target, isNotNull);
        final before = state.focus.identity;
        final mouse = await tester.createGesture(
          kind: ui.PointerDeviceKind.mouse,
        );
        await mouse.addPointer(location: const Offset(1250, 850));
        await mouse.moveTo(tester.getCenter(find.byType(GameCoverTile).at(2)));
        await frames(tester, 4);
        expect(state.focus.identity, isNot(before));
        expect(state.focus.progress, lessThan(1));
        await mouse.removePointer();
        await frames(tester, 40);
        Focus.of(tester.element(find.text('ABZU'))).requestFocus();
        await frames(tester, 12);
        final previousSelection = harness.nav.state.selectedGameId;
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await frames(tester, 40);
        expect(harness.nav.state.selectedGameId, isNot(previousSelection));
        final rect = state.focus.target!;
        await tester.drag(find.byType(GridView), const Offset(0, -120));
        await frames(tester, 30);
        expect(state.focus.target?.top, isNot(rect.top));
        tester.view.physicalSize = const Size(1100, 760);
        await frames(tester, 10);
        expect(state.field.size.width, lessThan(1100));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'hidden sections, lifecycle, reduced motion and preference stop the ticker',
      (tester) async {
        final harness = await app(tester);
        final state = tester.state<LibraryAtmosphereState>(
          find.byType(LibraryAtmosphere),
        );
        harness.nav.add(const SectionCycled(1));
        await frames(tester, 12);
        expect(state.isAnimating, isFalse);
        final pausedTime = state.field.time;
        await frames(tester, 12);
        expect(state.field.time, pausedTime);
        harness.nav.add(const SectionCycled(-1));
        await frames(tester, 12);
        expect(state.isAnimating, isTrue);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await frames(tester, 2);
        expect(state.isAnimating, isFalse);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await frames(tester, 2);
        expect(state.isAnimating, isTrue);
        harness.settings.add(
          SettingsChanged(
            harness.settings.state.copyWith(libraryEffects: false),
          ),
        );
        await frames(tester, 4);
        expect(state.isAnimating, isFalse);
        harness.settings.add(
          SettingsChanged(
            harness.settings.state.copyWith(libraryEffects: true),
          ),
        );
        await frames(tester, 4);
        await tester.pumpWidget(
          harness.buildApp(theme: EvaporateTheme.light()),
        );
        await tester.pumpAndSettle();
        expect(state.isAnimating, isFalse);
        expect(
          state.field.particles.where((p) => p.life < 0).length,
          ParticleField.ambientCount,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'light theme visual preview with live particles and liquid transfer',
      (tester) async {
        final preview = Platform.environment['LIQUID_PREVIEW'];
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
        final boundary = GlobalKey();
        await app(
          tester,
          builder: (_, child) => RepaintBoundary(key: boundary, child: child),
        );
        await frames(tester, 180);
        final mouse = await tester.createGesture(
          kind: ui.PointerDeviceKind.mouse,
        );
        await mouse.addPointer(location: const Offset(1250, 850));
        await mouse.moveTo(tester.getCenter(find.byType(GameCoverTile).at(1)));
        await frames(tester, 12);
        if (preview != null) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            try {
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(preview).writeAsBytes(data!.buffer.asUint8List());
            } finally {
              image.dispose();
            }
          });
        }
        await mouse.removePointer();
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  });
}
