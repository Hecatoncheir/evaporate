import 'dart:io';

import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/models/app_section.dart';
import 'package:evaporate/models/app_settings.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/ui/library/game_cover.dart';
import 'package:evaporate/ui/settings/settings_page.dart';
import 'package:evaporate/ui/widgets/interface_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

void main() {
  test('масштабы независимы, переживают перезапуск и зажимаются в границы', () {
    final defaults = AppSettings.fromJson(const {}, '/games');
    expect(defaults.interfaceScale, 1);
    expect(defaults.libraryScale, 1);
    final changed = defaults.copyWith(interfaceScale: 1.2, libraryScale: 0.75);
    expect(changed, isNot(defaults));
    final restored = AppSettings.fromJson(changed.toJson(), '/games');
    expect(restored.toJson(), changed.toJson());
    expect(
      AppSettings.fromJson(const {
        'interfaceScale': 99,
        'libraryScale': -1,
      }, '/games').interfaceScale,
      1.25,
    );
    expect(
      AppSettings.fromJson(const {
        'interfaceScale': 99,
        'libraryScale': -1,
      }, '/games').libraryScale,
      0.75,
    );
    expect(
      AppSettings.fromJson(const {
        'interfaceScale': 'bad',
        'libraryScale': double.nan,
      }, '/games').toJson(),
      defaults.toJson(),
    );
  });

  late Directory tmp;
  setUp(() async => tmp = await TestHarness.makeTempDir());
  tearDown(() => TestHarness.removeTempDir(tmp));

  testWidgets(
    'масштаб интерфейса растит и значки числом, и области нажатия в диалогах',
    (tester) async {
      final harness = TestHarness(tmp);
      addTearDown(harness.dispose);
      harness.settings.add(
        SettingsPatched((current) => current.copyWith(interfaceScale: 1.25)),
      );
      await tester.pumpWidget(
        BlocProvider.value(
          value: harness.settings,
          child: MaterialApp(
            builder: (_, child) => InterfaceScale(child: child!),
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: SizedBox(
                    width: 160,
                    height: 60,
                    child: FilledButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          content: const Text('Scaled dialog'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                      child: const Icon(Icons.play_arrow, size: 20),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byIcon(Icons.play_arrow)).width,
        closeTo(25, 0.1),
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('Scaled dialog'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Scaled dialog'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('масштаб обложек меняет число столбцов, не трогая выбор', (
    tester,
  ) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    for (var i = 0; i < 16; i++) {
      harness.addGame(title: 'Game $i');
    }
    await harness.pump(tester);
    final selected = harness.nav.state.selectedGameId;
    final before = tester.getSize(find.byType(GameCoverTile).first);
    await tester.tap(find.byTooltip('Увеличить: Обложки игр').first);
    await tester.pumpAndSettle();
    expect(harness.settings.state.libraryScale, 1.25);
    expect(
      tester.getSize(find.byType(GameCoverTile).first).width,
      greaterThan(before.width),
    );
    expect(harness.nav.state.selectedGameId, selected);
    harness.nav.add(const SectionSelected(AppSection.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Увеличить: Масштаб интерфейса'));
    await tester.pumpAndSettle();
    expect(harness.settings.state.interfaceScale, 1.05);
    expect(harness.settings.state.libraryScale, 1.25);
    final reset = find.descendant(
      of: find.byKey(const ValueKey('interface-scale')),
      matching: find.byType(TextButton),
    );
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(harness.settings.state.interfaceScale, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'на предельном масштабе в наименьшее окно всё ещё помещается навигация',
    (tester) async {
      final harness = TestHarness(tmp);
      addTearDown(harness.dispose);
      harness.addGame(
        title: 'A long installed game title',
        status: GameStatus.installed,
      );
      harness.addGame(title: 'Another game');
      harness.settings.add(
        SettingsPatched(
          (current) =>
              current.copyWith(interfaceScale: 1.25, libraryScale: 1.5),
        ),
      );
      tester.view.physicalSize = const Size(900, 578);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness.buildApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tapAt(
        tester.getTopLeft(find.byType(GameCoverTile).first) +
            const Offset(40, 40),
      );
      await tester.pumpAndSettle();
      expect(harness.nav.state.openedGameId, isNotNull);
      expect(tester.takeException(), isNull);
      for (final section in AppSection.values.skip(1)) {
        harness.nav.add(SectionSelected(section));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'раздел ${section.name}',
        );
      }
      // Именно прокрутка настроек, а не «последняя из найденных»: список
      // настроек собран не ListView — иначе фокусу некуда идти дальше
      // построенной карточки.
      final settingsScroll = find
          .descendant(
            of: find.byType(SettingsPage),
            matching: find.byType(Scrollable),
          )
          .first;
      for (var i = 0; i < 24; i++) {
        await tester.drag(settingsScroll, const Offset(0, -350));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'settings scroll $i');
      }
      expect(find.byType(InterfaceScale), findsOneWidget);
    },
  );
}
