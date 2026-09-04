import 'dart:io';
import 'dart:ui' as ui;

import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/models/app_settings.dart';
import 'package:evaporate/ui/library/game_cover.dart';
import 'package:evaporate/ui/library/library_atmosphere.dart';
import 'package:evaporate/ui/library/foil_card.dart';
import 'package:evaporate/ui/library/particle_field.dart';
import 'package:evaporate/ui/library/game_wave.dart';
import 'package:evaporate/ui/widgets/decorative_motion.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'foil tilts rigidly, retains artwork and settles on deselection',
    (tester) async {
      var active = true;
      var enabled = true;
      var reduced = false;
      var visible = true;
      var builds = 0;
      final key = GlobalKey<FoilCardState>();
      final artwork = Builder(
        builder: (_) {
          builds++;
          return const FoilSurface(child: SizedBox(width: 180, height: 270));
        },
      );
      Future<void> show() => tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: TickerMode(
              enabled: visible,
              child: Center(
                child: FoilCard(
                  key: key,
                  active: active,
                  enabled: enabled,
                  child: artwork,
                ),
              ),
            ),
          ),
        ),
      );
      Future<void> frames(int count) async {
        for (var i = 0; i < count; i++) {
          await tester.pump(const Duration(milliseconds: 17));
        }
      }

      await show();
      await frames(60);
      expect(key.currentState!.isAnimating, isTrue);
      final first = key.currentState!.perspective;
      expect(first, isNot(Matrix4.identity()));
      await frames(60);
      expect(key.currentState!.perspective, isNot(first));
      expect(builds, 1);

      visible = false;
      await show();
      expect(key.currentState!.isAnimating, isFalse);
      final paused = key.currentState!.perspective;
      await frames(30);
      expect(key.currentState!.perspective, paused);
      visible = true;
      await show();
      expect(key.currentState!.isAnimating, isTrue);

      active = false;
      await show();
      await tester.pumpAndSettle();
      expect(key.currentState!.perspective, Matrix4.identity());
      expect(key.currentState!.isAnimating, isFalse);

      active = true;
      await show();
      await frames(25);
      enabled = false;
      await show();
      await tester.pumpAndSettle();
      expect(key.currentState!.perspective, Matrix4.identity());
      expect(key.currentState!.isAnimating, isFalse);

      enabled = true;
      reduced = true;
      await show();
      await tester.pumpAndSettle();
      expect(key.currentState!.perspective, Matrix4.identity());
      expect(key.currentState!.isAnimating, isFalse);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  test('ambient points use the exact requested colors', () {
    expect(ambientParticleColor(false), const Color(0xFF2F0346));
    expect(ambientParticleColor(true), const Color(0xFFF2685A));
  });

  testWidgets('particle painter has a sharp core and no glow outside it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: EvaporateTheme.dark(),
        home: LibraryAtmosphere(
          enabled: true,
          targetKey: () => null,
          child: const SizedBox.expand(),
        ),
      ),
    );
    final state = tester.state<LibraryAtmosphereState>(
      find.byType(LibraryAtmosphere),
    );
    state.field.particles
      ..clear()
      ..add(InkParticle(const Offset(16, 16), Offset.zero, 0, -1)..glow = 1);
    final painter = tester
        .widget<CustomPaint>(
          find.byKey(const ValueKey('library-atmosphere-paint')),
        )
        .painter!;
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), const Size(32, 32));
    final picture = recorder.endRecording();
    await tester.runAsync(() async {
      final image = await picture.toImage(32, 32);
      try {
        final pixels = (await image.toByteData())!.buffer.asUint8List();
        expect(pixels.sublist((16 * 32 + 16) * 4, (16 * 32 + 16) * 4 + 4), [
          closeTo(239, 1),
          closeTo(20, 1),
          closeTo(124, 1),
          closeTo(255, 1),
        ]);
        for (final x in [12, 13, 19, 20]) {
          expect(
            pixels[(16 * 32 + x) * 4 + 3],
            0,
            reason: 'no halo beyond the point radius',
          );
        }
      } finally {
        image.dispose();
        picture.dispose();
      }
    });
    await tester.pumpWidget(const SizedBox());
  });

  test('nearby particles have identical saturated colors in both themes', () {
    for (var i = 0; i < 5; i++) {
      final light = particleColor(isDark: false, phase: i / 10, glow: 1);
      final dark = particleColor(isDark: true, phase: i / 10, glow: 1);
      expect(light, libraryInkColors[i]);
      expect(dark, light);
    }
    expect(ParticleField.ambientCount, 4800);
    expect(ParticleField.maxCount, 6800);
  });

  group('particle simulation', () {
    for (final seed in [4, 42, 108]) {
      test('ambient particles stay uniform without a target (seed $seed)', () {
        final field = ParticleField(seed: seed)..resize(const Size(1000, 700));
        void checkDistribution() {
          final bins = List.filled(16, 0);
          for (final p in field.particles) {
            final x = (p.position.dx / field.size.width * 4).floor().clamp(
              0,
              3,
            );
            final y = (p.position.dy / field.size.height * 4).floor().clamp(
              0,
              3,
            );
            bins[y * 4 + x]++;
          }
          final expected = ParticleField.ambientCount / 16;
          for (final count in bins) {
            expect(count, inInclusiveRange(expected * 0.7, expected * 1.3));
          }
          expect(field.particles.length, 4800);
        }

        checkDistribution();
        for (var i = 0; i < 900; i++) {
          field.step(1 / 60);
        }
        checkDistribution();
        // Check motion over a frame, not net displacement after a long orbit:
        // a moving point can return close to its starting position.
        final original = field.particles.map((p) => p.position).toList();
        field.step(1 / 60);
        expect(
          field.particles.indexed
              .where(
                (entry) =>
                    (entry.$2.position - original[entry.$1]).distance > 0.001,
              )
              .length,
          greaterThan(4750),
        );
        field.resize(const Size(350, 900));
        checkDistribution();
        expect(InkParticle.radius, 1.25);
      });
    }
    test('targets restore attraction, colour and local particle emission', () {
      final field = ParticleField()..resize(const Size(1000, 700));
      final ambient = ParticleField()..resize(const Size(1000, 700));
      field.card = const Rect.fromLTWH(320, 150, 180, 270);
      field.pointer = const Offset(750, 400);
      for (var i = 0; i < 300; i++) {
        field.step(1 / 60);
        ambient.step(1 / 60);
      }
      expect(field.particles.length, greaterThan(ParticleField.ambientCount));
      expect(field.particles.length, lessThanOrEqualTo(ParticleField.maxCount));
      final near = field.particles
          .where((p) => field.proximity(p.position) > 0.7)
          .length;
      final baselineNear = ambient.particles
          .where((p) => field.proximity(p.position) > 0.7)
          .length;
      expect(near, greaterThan(baselineNear * 1.5));
      expect(field.particles.any((p) => p.glow > 0.8), isTrue);
      expect(field.proximity(const Offset(320, 200)), 1);
      field.card = null;
      field.pointer = null;
      for (var i = 0; i < 240; i++) {
        field.step(1 / 60);
      }
      expect(field.particles.every((p) => p.glow == 0), isTrue);
      expect(field.particles.length, 4800);
    });

    test(
      'original near-target acceleration leaves distant motion unchanged',
      () {
        final near = ParticleField()..resize(const Size(1000, 700));
        final far = ParticleField()..resize(const Size(1000, 700));
        final ambient = ParticleField()..resize(const Size(1000, 700));
        near.card = far.card = const Rect.fromLTWH(300, 200, 200, 300);
        near.particles
          ..clear()
          ..add(InkParticle(const Offset(400, 200), Offset.zero, 0, -1));
        far.particles
          ..clear()
          ..add(InkParticle(const Offset(900, 650), Offset.zero, 0, -1));
        ambient.particles
          ..clear()
          ..add(InkParticle(const Offset(900, 650), Offset.zero, 0, -1));
        near.step(1 / 60);
        far.step(1 / 60);
        ambient.step(1 / 60);
        expect(near.particles.first.velocity.distance, greaterThan(6));
        expect(far.particles.first.velocity, ambient.particles.first.velocity);
        expect(ParticleField.maxSpeed, 360);
      },
    );

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
          expect(
            particle.velocity.distance,
            lessThanOrEqualTo(ParticleField.maxSpeed + 0.001),
          );
        }
      },
    );
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
      ThemeData? theme,
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
          theme: theme ?? EvaporateTheme.light(),
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
        expect(find.byKey(const ValueKey('library-wave')), findsOneWidget);
        expect(find.byType(GameWave), findsOneWidget);
        final state = tester.state<LibraryAtmosphereState>(
          find.byType(LibraryAtmosphere),
        );
        expect(state.isAnimating, isTrue);
        expect(state.targetRect, isNotNull);
        expect(
          tester
              .stateList<FoilCardState>(find.byType(FoilCard))
              .where((s) => s.isAnimating)
              .length,
          1,
        );
        final before = state.targetIdentity;
        final mouse = await tester.createGesture(
          kind: ui.PointerDeviceKind.mouse,
        );
        await mouse.addPointer(location: const Offset(1250, 850));
        await mouse.moveTo(tester.getCenter(find.byType(GameCoverTile).at(2)));
        await frames(tester, 4);
        expect(state.targetIdentity, isNot(before));
        expect(
          tester
              .widgetList<FoilCard>(find.byType(FoilCard))
              .where((c) => c.active)
              .length,
          1,
        );
        await mouse.removePointer();
        await frames(tester, 40);
        Focus.of(tester.element(find.text('ABZU'))).requestFocus();
        await frames(tester, 12);
        final previousSelection = harness.nav.state.selectedGameId;
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await frames(tester, 40);
        expect(harness.nav.state.selectedGameId, isNot(previousSelection));
        final rect = state.targetRect!;
        await tester.drag(find.byType(GridView), const Offset(0, -120));
        await frames(tester, 30);
        expect(state.targetRect?.top, isNot(rect.top));
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
        expect(
          tester
              .stateList<DecorativeMotionState>(
                find.byType(DecorativeMotion, skipOffstage: false),
              )
              .any((s) => s.isAnimating),
          isFalse,
        );
        expect(
          tester
              .stateList<FoilCardState>(
                find.byType(FoilCard, skipOffstage: false),
              )
              .any((s) => s.isAnimating),
          isFalse,
        );
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
        expect(
          tester
              .stateList<FoilCardState>(find.byType(FoilCard))
              .any((s) => s.isAnimating),
          isFalse,
        );
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

    testWidgets('visual preview with live particles and foil perspective', (
      tester,
    ) async {
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
        theme: Platform.environment['LIQUID_PREVIEW_DARK'] == '1'
            ? EvaporateTheme.dark()
            : EvaporateTheme.light(),
        builder: (_, child) => RepaintBoundary(key: boundary, child: child),
      );
      await frames(tester, 180);
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(1250, 850));
      await mouse.moveTo(tester.getCenter(find.byType(GameCoverTile).at(1)));
      await frames(tester, 90);
      if (preview != null) {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          try {
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await File(preview).writeAsBytes(data!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
      }
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  });
}
