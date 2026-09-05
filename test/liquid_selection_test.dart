import 'dart:io';
import 'dart:ui' as ui;

import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/ui/library/game_cover.dart';
import 'package:evaporate/ui/settings/settings_page.dart';
import 'package:evaporate/ui/widgets/common.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:evaporate/ui/widgets/liquid_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final vertical in [false, true]) {
    test('gooey neck joins ${vertical ? 'vertical' : 'horizontal'} lobes', () {
      final from = Rect.fromLTWH(0, 0, vertical ? 60 : 120, vertical ? 40 : 60);
      final to = from.shift(
        vertical ? const Offset(0, 72) : const Offset(148, 0),
      );
      final path = liquidSelectionPath(from, to, 0.5, 18);
      final centre = Offset.lerp(from.center, to.center, 0.5)!;
      expect(path.contains(from.center), isTrue);
      expect(path.contains(to.center), isTrue);
      expect(path.contains(centre), isTrue);
      // A neck, not a rectangle connecting the full width of both elements.
      expect(
        path.contains(
          centre + (vertical ? const Offset(25, 0) : const Offset(0, 25)),
        ),
        isFalse,
      );
      expect(liquidSelectionPath(from, to, 0, 18).getBounds(), from);
      expect(liquidSelectionPath(from, to, 1, 18).getBounds(), to);
    });
  }

  testWidgets(
    'transition retains content, retargets, settles and respects motion gates',
    (tester) async {
      final targets = List.generate(3, (_) => GlobalKey());
      final selection = GlobalKey<LiquidSelectionState>();
      var selected = 0;
      var reduced = false;
      var visible = true;
      var enabled = true;
      var missing = false;
      var builds = 0;
      final content = Builder(
        builder: (_) {
          builds++;
          return Row(
            children: [
              for (final key in targets)
                SizedBox(key: key, width: 100, height: 60),
            ],
          );
        },
      );
      Future<void> show() => tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: TickerMode(
              enabled: visible,
              child: Center(
                child: SizedBox(
                  width: 300,
                  height: 60,
                  child: LiquidSelection(
                    key: selection,
                    targetKey: () => missing ? null : targets[selected],
                    enabled: enabled,
                    color: Colors.orange,
                    child: content,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await show();
      await tester.pumpAndSettle();
      expect(selection.currentState!.isAnimating, isFalse);
      selected = 1;
      await show();
      await tester.pump(const Duration(milliseconds: 100));
      expect(selection.currentState!.isAnimating, isTrue);
      expect(builds, 1);
      selected = 2;
      await show();
      await tester.pumpAndSettle();
      expect(
        selection.currentState!.targetRect,
        const Rect.fromLTWH(200, 0, 100, 60),
      );
      expect(selection.currentState!.isAnimating, isFalse);
      for (var gate = 0; gate < 4; gate++) {
        selected = (selected + 1) % 3;
        await show();
        expect(selection.currentState!.isAnimating, isTrue);
        switch (gate) {
          case 0:
            reduced = true;
          case 1:
            visible = false;
          case 2:
            enabled = false;
          case 3:
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.inactive,
            );
        }
        await show();
        await tester.pumpAndSettle();
        expect(selection.currentState!.isAnimating, isFalse);
        reduced = false;
        visible = true;
        enabled = true;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await show();
        await tester.pumpAndSettle();
      }
      expect(builds, 1);
      missing = true;
      await show();
      await tester.pumpAndSettle();
      expect(selection.currentState!.targetRect, isNull);
      expect(selection.currentState!.isAnimating, isFalse);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  late Directory tmp;
  setUp(() async => tmp = await TestHarness.makeTempDir());
  tearDown(() => TestHarness.removeTempDir(tmp));

  for (final light in [true, false]) {
    testWidgets(
      'liquid selection integrates with rail, filters and grid (${light ? 'light' : 'dark'})',
      (tester) async {
        final preview = Platform.environment['LIQUID_PREVIEW_PREFIX'];
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
        harness.settings.add(
          SettingsChanged(
            harness.settings.state.copyWith(liquidSelectionEnabled: true),
          ),
        );
        for (final title in [
          'ABZU',
          'CELESTE',
          'CONTROL',
          'HADES',
          'INSIDE',
          'JOURNEY',
          'ORI',
          'PORTAL',
          'STRAY',
          'TUNIC',
          'DEAD CELLS',
          'HOLLOW KNIGHT',
        ]) {
          harness.addGame(title: title, status: GameStatus.installed);
        }
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          harness.buildApp(
            theme: light ? EvaporateTheme.light() : EvaporateTheme.dark(),
            motion: true,
            builder: (_, child) => RepaintBoundary(key: boundary, child: child),
          ),
        );
        Future<void> frames(int count) async {
          for (var i = 0; i < count; i++) {
            await tester.pump(const Duration(milliseconds: 17));
          }
        }

        Future<void> capture(String name) async {
          if (preview == null) return;
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File('$preview-${light ? 'light' : 'dark'}-$name.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
            } finally {
              image.dispose();
            }
          });
        }

        LiquidSelectionState state(String key) =>
            tester.state(find.byKey(ValueKey(key), skipOffstage: false));
        await frames(40);
        final games = tester
            .widgetList<GameCoverTile>(find.byType(GameCoverTile))
            .toList();
        harness.nav.add(GameSelected(games[1].game.id));
        await frames(13);
        expect(state('grid-liquid').isAnimating, isTrue);
        await capture('cards');
        await frames(25);
        expect(state('grid-liquid').isAnimating, isFalse);
        final beforeScroll = state('grid-liquid').targetRect!;
        final scroll = tester
            .widget<GridView>(find.byType(GridView))
            .controller!;
        scroll.jumpTo(60);
        await frames(2);
        expect(
          state('grid-liquid').targetRect!.top,
          closeTo(beforeScroll.top - 60, 0.1),
        );
        expect(state('grid-liquid').isAnimating, isFalse);
        scroll.jumpTo(0);
        await frames(2);
        await tester.tap(find.text('Установленные'));
        await frames(13);
        expect(state('shelf-liquid').isAnimating, isTrue);
        final palette = light ? EvaporatePalette.light : EvaporatePalette.dark;
        expect(
          DefaultTextStyle.of(tester.element(find.text('Все'))).style.color,
          palette.onSelection,
        );
        await capture('filters');
        await frames(25);
        harness.nav.add(const SectionSelected(1));
        await frames(13);
        expect(state('rail-liquid').isAnimating, isTrue);
        expect(
          IconTheme.of(tester.element(find.byIcon(Icons.grid_view_outlined)))
              .color,
          palette.onSelection,
        );
        expect(state('grid-liquid').isAnimating, isFalse);
        await capture('rail');
        await frames(25);
        expect(state('rail-liquid').isAnimating, isFalse);
        harness.nav.add(const SectionSelected(3));
        await frames(40);
        final effects = find.byKey(const ValueKey('living-library-settings'));
        await tester.scrollUntilVisible(
          effects,
          400,
          scrollable: find
              .descendant(
                of: find.byType(SettingsPage),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await frames(20);
        expect(tester.widget<SectionCard>(effects).title, 'Живая библиотека');
        final toggle = find.descendant(
          of: find.byKey(const ValueKey('effects-master-toggle')),
          matching: find.byType(Switch),
        );
        expect(toggle, findsOneWidget);
        await capture('settings');
        await tester.tap(toggle);
        await frames(5);
        expect(harness.settings.state.libraryEffects, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
