import 'dart:io';

import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/models/app_settings.dart';
import 'package:evaporate/ui/library/foil_card.dart';
import 'package:evaporate/ui/library/library_atmosphere.dart';
import 'package:evaporate/ui/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  test('new and migrated settings use the chosen effect defaults', () {
    for (final settings in [
      const AppSettings(installDir: '/games'),
      AppSettings.fromJson({}, '/games'),
      AppSettings.fromJson({'libraryEffects': true}, '/games'),
      AppSettings.fromJson({'libraryEffects': false}, '/games'),
    ]) {
      expect(settings.particlesEnabled, isFalse);
      expect(settings.wavesEnabled, isTrue);
      expect(settings.foilEnabled, isTrue);
      expect(settings.cardTiltEnabled, isTrue);
      expect(settings.liquidDistortionEnabled, isFalse);
      expect(settings.liquidSelectionEnabled, isFalse);
      expect(settings.ambientEnabled, isTrue);
      expect(settings.interfaceAnimationsEnabled, isFalse);
      expect(
        AppSettings.fromJson(settings.toJson(), '/games').toJson(),
        settings.toJson(),
      );
    }
    const base = AppSettings(installDir: '/games');
    for (final changed in [
      base.copyWith(particlesEnabled: true),
      base.copyWith(wavesEnabled: false),
      base.copyWith(foilEnabled: false),
      base.copyWith(cardTiltEnabled: false),
      base.copyWith(liquidDistortionEnabled: true),
      base.copyWith(liquidSelectionEnabled: true),
      base.copyWith(ambientEnabled: false),
      base.copyWith(interfaceAnimationsEnabled: true),
    ]) {
      expect(changed, isNot(base));
      final restored = AppSettings.fromJson(changed.toJson(), '/games');
      expect(restored.toJson(), changed.toJson());
      expect(
        changed.copyWith(libraryEffects: false).copyWith(libraryEffects: true),
        changed,
      );
    }
  });

  Future<void> frames(WidgetTester tester, [int count = 12]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 17));
    }
  }

  testWidgets(
    'distortion works independently and disabling it restores geometry',
    (tester) async {
      final key = GlobalKey<FoilCardState>();
      var distortion = true;
      var reduced = false;
      var visible = true;
      var builds = 0;
      final child = Builder(
        builder: (_) {
          builds++;
          return const SizedBox(width: 180, height: 270);
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
                  active: true,
                  enabled: true,
                  foilEnabled: false,
                  tiltEnabled: false,
                  distortionEnabled: distortion,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
      await show();
      await frames(tester);
      expect(key.currentState!.perspective, isNot(Matrix4.identity()));
      expect(builds, 1);
      visible = false;
      await show();
      expect(key.currentState!.isAnimating, isFalse);
      visible = true;
      reduced = true;
      await show();
      expect(key.currentState!.perspective, Matrix4.identity());
      expect(key.currentState!.isAnimating, isFalse);
      reduced = false;
      distortion = false;
      await show();
      expect(key.currentState!.perspective, Matrix4.identity());
      expect(key.currentState!.isAnimating, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );

  group('effect controls', () {
    late Directory tmp;
    setUp(() async => tmp = await TestHarness.makeTempDir());
    tearDown(() => TestHarness.removeTempDir(tmp));

    testWidgets(
      'individual switches apply immediately and preserve choices under master',
      (tester) async {
        final harness = TestHarness(tmp);
        addTearDown(harness.dispose);
        harness.addGame(title: 'Hades');
        await tester.pumpWidget(harness.buildApp(motion: true));
        await frames(tester);
        final atmosphere = tester.state<LibraryAtmosphereState>(
          find.byType(LibraryAtmosphere),
        );
        expect(atmosphere.field.particles, isEmpty);
        expect(find.byKey(const ValueKey('detail-wave-paint')), findsOneWidget);

        Future<void> toggle(String name) async {
          harness.nav.add(const SectionSelected(3));
          await frames(tester);
          final target = find.byKey(ValueKey('effects-$name-toggle'));
          await tester.scrollUntilVisible(
            target,
            350,
            scrollable: find
                .descendant(
                  of: find.byType(SettingsPage),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.ensureVisible(target);
          await frames(tester);
          await tester.tap(target);
          await frames(tester);
          harness.nav.add(const SectionSelected(0));
          await frames(tester);
        }

        await toggle('particles');
        expect(harness.settings.state.particlesEnabled, isTrue);
        expect(atmosphere.field.particles, isNotEmpty);
        await toggle('waves');
        expect(find.byKey(const ValueKey('detail-wave-paint')), findsNothing);
        expect(atmosphere.field.particles, isNotEmpty);
        await toggle('particles');
        expect(atmosphere.field.particles, isEmpty);
        await toggle('particles');
        expect(atmosphere.field.particles, isNotEmpty);
        await toggle('master');
        expect(atmosphere.field.particles, isEmpty);
        expect(atmosphere.isAnimating, isFalse);
        expect(harness.settings.state.particlesEnabled, isTrue);
        await toggle('master');
        expect(atmosphere.field.particles, isNotEmpty);
        expect(find.byKey(const ValueKey('detail-wave-paint')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
