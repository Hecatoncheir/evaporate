import 'dart:io';

import 'package:evaporate/bloc/downloads/downloads_bloc.dart';
import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/input/gamepad_binding.dart';
import 'package:evaporate/input/nav_action.dart';
import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/models/app_section.dart';
import 'package:evaporate/models/app_settings.dart';
import 'package:evaporate/models/download_task.dart';
import 'package:evaporate/models/effect_quality.dart';
import 'package:evaporate/models/library_effect.dart';
import 'package:evaporate/services/download/download_engine.dart';
import 'package:evaporate/ui/ev/app/ev_app_scope.dart';
import 'package:evaporate/ui/ev/app/ev_app_shell.dart';
import 'package:evaporate/ui/ev/app/ev_shell_status.dart';
import 'package:evaporate/ui/ev/app/shell_hints.dart';
import 'package:evaporate/ui/ev/design/effects.dart';
import 'package:evaporate/ui/ev/shell/ev_section.dart';
import 'package:evaporate/ui/ev/shell/ev_top_bar.dart';
import 'package:evaporate/ui/ev/sound/ev_sound.dart';
import 'package:evaporate/ui/ev/sound/voices.dart';
import 'package:evaporate/ui/ev/widgets/ev_surfaces.dart';
import 'package:evaporate/ui/labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamepads/gamepads.dart';

import '../../../support/test_app.dart';

/// Звук, который записывает, что ему велели.
class _Out implements EvAudioOut {
  final log = <String>[];

  @override
  Future<void> start() async => log.add('start');

  @override
  void volume(double gain) => log.add('volume');

  @override
  void play(EvVoice voice) => log.add(voice.name);

  @override
  EvHoldVoice hold() => const EvSilentOut().hold();

  @override
  void ambient(bool on) {}

  @override
  void dispose() {}
}

void main() {
  final l = LRu();

  group('облик приложения — эффекты прототипа', () {
    test('по умолчанию горит всё, что горит в прототипе', () {
      final effects = EvEffects.still();
      addTearDown(effects.dispose);

      applyAppearance(effects, const Appearance());

      expect(effects.quality, EvEffectsQuality.full);
      expect(effects.glass, isTrue);
      expect(effects.livingBackground, isTrue);
      expect(effects.sparks, isTrue);
      expect(effects.grain, isTrue);
      expect(effects.parallax, isTrue);
    });

    test(
      'качество — ступень в ступень, стекло и свет — свои переключатели',
      () {
        final effects = EvEffects();
        addTearDown(effects.dispose);

        applyAppearance(
          effects,
          const Appearance(
            effectQuality: EffectQuality.eco,
            effects: {LibraryEffect.foil},
          ),
        );

        expect(effects.quality, EvEffectsQuality.eco);
        expect(effects.glass, isFalse);
        expect(effects.livingBackground, isFalse);
        // Угли и зерно своих переключателей не имеют.
        expect(effects.sparks, isTrue);

        applyAppearance(
          effects,
          const Appearance(effectQuality: EffectQuality.max),
        );
        expect(effects.quality, EvEffectsQuality.max);
      },
    );

    test('общий выключатель гасит и то, у чего переключателя нет', () {
      final effects = EvEffects();
      addTearDown(effects.dispose);

      applyAppearance(effects, const Appearance(libraryEffects: false));

      expect(effects.glass, isFalse);
      expect(effects.livingBackground, isFalse);
      expect(effects.sparks, isFalse);
      expect(effects.grain, isFalse);
      expect(effects.parallax, isFalse);
    });
  });

  group('строка подсказок', () {
    test('без геймпада — клавиши', () {
      final hints = shellHints(l, const GamepadBinding(), gamepad: false);
      expect(hints.first, ('↑↓←→', l.hintNavigate));
      expect(hints, contains(('/', l.hintSearch)));
      expect(hints, contains(('Ctrl+Tab', l.hintSections)));
    });

    test('с геймпадом — кнопки из раскладки', () {
      const binding = GamepadBinding();
      final hints = shellHints(l, binding, gamepad: true);
      expect(hints.first, ('D-pad', l.hintNavigate));
      expect(hints, contains(('RB', l.hintSections)));

      // Переставленная кнопка — и подсказка вслед за ней.
      final swapped = GamepadBinding(
        buttons: {
          for (final entry in GamepadBinding.defaultButtons.entries)
            if (entry.value != NavAction.nextSection) entry.key: entry.value,
          GamepadButton.y: NavAction.nextSection,
        },
      );
      expect(
        shellHints(l, swapped, gamepad: true),
        contains(('Y', l.hintSections)),
      );
    });
  });

  test('состояние движка называется словами плашки и тоном', () {
    expect(engineReadout(l, EngineState.ready), (l.evEngineReady, EvStatus.ok));
    expect(engineReadout(l, EngineState.starting).$2, EvStatus.busy);
    expect(engineReadout(l, EngineState.stopped), (
      l.evEngineStopped,
      EvStatus.idle,
    ));
    expect(engineReadout(l, EngineState.failed).$2, EvStatus.bad);
  });

  group('звук, включённый с начала', () {
    test('заводит движок, но «Готово» не играет', () async {
      final out = _Out();
      final sound = EvSound(out: out, enabled: true);
      addTearDown(sound.dispose);
      await Future<void>.delayed(Duration.zero);

      expect(sound.enabled, isTrue);
      expect(out.log, ['start', 'volume']);
      sound.play(EvVoice.swish);
      expect(out.log.last, 'swish');
    });

    test('без просьбы молчит и движок не трогает', () async {
      final out = _Out();
      final sound = EvSound(out: out);
      addTearDown(sound.dispose);
      await Future<void>.delayed(Duration.zero);

      sound.play(EvVoice.swish);
      expect(out.log, isEmpty);
    });
  });

  group('каркас на блоках приложения', () {
    late Directory tmp;
    setUp(() async => tmp = await TestHarness.makeTempDir());
    tearDown(() => TestHarness.removeTempDir(tmp));

    Finder crumb(String label) =>
        find.descendant(of: find.byType(EvTopBar), matching: find.text(label));

    testWidgets('раздел из блока доходит до каркаса, и обратно', (
      tester,
    ) async {
      final harness = TestHarness(tmp);
      addTearDown(harness.dispose);
      await harness.pump(tester);

      // Геймпад листает блок — каркас следует за ним.
      await harness.tapButton(tester, GamepadButton.rightBumper);
      expect(harness.nav.state.section, AppSection.downloads);
      expect(crumb(l.downloads), findsOneWidget);

      // Поиск уводит в библиотеку — и каркас туда же.
      harness.nav.add(const SearchFocusRequested());
      await tester.pumpAndSettle();
      expect(crumb(l.library), findsOneWidget);

      // Рейл двигает блок.
      await tester.tap(find.byKey(const ValueKey('rail-settings')));
      await tester.pumpAndSettle();
      expect(harness.nav.state.section, AppSection.settings);
    });

    test('разделы приложения и прототипа сходятся по имени', () {
      for (final section in AppSection.values) {
        expect(appSectionOf(evSectionOf(section)), section);
      }
      expect(appSectionOf(EvSection.friends), isNull);
      expect(appSectionOf(EvSection.profile), isNull);
    });

    testWidgets('смена раздела звучит', (tester) async {
      final harness = TestHarness(tmp);
      addTearDown(harness.dispose);
      final out = _Out();
      final sound = EvSound(out: out, enabled: true);
      addTearDown(sound.dispose);
      tester.view.physicalSize = const Size(1600, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        harness.buildApp(
          builder: (context, child) =>
              EvSoundScope(sound: sound, child: child!),
        ),
      );
      await tester.pumpAndSettle();

      harness.nav.add(const SectionSelected(AppSection.saves));
      await tester.pumpAndSettle();

      expect(out.log, contains('swish'));
    });

    testWidgets('показатели полосы и рейла — настоящие', (tester) async {
      final harness = TestHarness(tmp);
      addTearDown(harness.dispose);
      await harness.pump(tester);

      Finder pill(String label) => find.widgetWithText(EvPill, label);
      expect(pill(l.evEngineStopped), findsOneWidget);

      harness.downloads
        ..add(const EngineStatusChanged(EngineStatus(EngineState.ready)))
        ..add(
          const EngineStatsChanged(EngineStats(downloadSpeed: 2 * 1024 * 1024)),
        )
        ..add(
          const EngineTasksChanged([
            DownloadTask(
              id: 'a',
              name: 'a',
              state: DownloadState.active,
              totalBytes: 10,
            ),
            DownloadTask(
              id: 'b',
              name: 'b',
              state: DownloadState.paused,
              totalBytes: 10,
            ),
          ]),
        );
      await tester.pumpAndSettle();

      expect(pill(l.evEngineReady), findsOneWidget);
      final speed = tester.widget<EvPill>(find.byType(EvPill).first);
      expect(speed.status, EvStatus.busy);
      expect(speed.label, speedLabel(l, 2 * 1024 * 1024));
      // Число задач в работе — на кнопке «Загрузки».
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('rail-downloads')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      // И в строке подсказок — то же состояние движка.
      expect(find.text('● ${l.engineReady.toUpperCase()}'), findsOneWidget);
    });

    testWidgets('переключатель украшений в настройках доходит до каркаса', (
      tester,
    ) async {
      final harness = TestHarness(tmp);
      addTearDown(harness.dispose);
      await harness.pump(tester);

      EvEffects effects() =>
          EvEffectsScope.maybeOf(tester.element(find.byType(EvAppShell)))!;
      expect(effects().glass, isTrue);

      harness.settings.add(
        SettingsPatched(
          (s) => s.withAppearance((a) => a.copyWith(libraryEffects: false)),
        ),
      );
      await tester.pumpAndSettle();

      expect(effects().glass, isFalse);
      expect(effects().sparks, isFalse);
    });
  });
}
