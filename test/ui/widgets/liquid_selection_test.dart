import 'dart:io';
import 'dart:ui' as ui;

import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/models/app_section.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/models/library_effect.dart';
import 'package:evaporate/ui/library/game_cover_tile.dart';
import 'package:evaporate/ui/settings/settings_page.dart';
import 'package:evaporate/ui/shell/chrome_scroll_view.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:evaporate/ui/widgets/liquid/liquid_selection.dart';
import 'package:evaporate/ui/widgets/liquid/liquid_selection_path.dart';
import 'package:evaporate/ui/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

void main() {
  // Ищем по ключу перевода, а не по строке: правка формулировки в
  // ARB иначе роняет тест, ничего не сломав в приложении.
  final l = LRu();

  TestWidgetsFlutterBinding.ensureInitialized();

  for (final vertical in [false, true]) {
    test('перемычка соединяет ${vertical ? 'верх с низом' : 'бока'}', () {
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
    'переезд не теряет содержимое, меняет цель, успокаивается и слушает запреты движения',
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
                    radius: 18,
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
      // Окно без фокуса видно по-прежнему, и капля обязана доехать.
      selected = 1;
      await show();
      expect(selection.currentState!.isAnimating, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await show();
      await tester.pump(const Duration(milliseconds: 100));
      expect(selection.currentState!.isAnimating, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
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
            // Свернуть окно можно только через потерю фокуса: так его
            // состояния меняются и в жизни.
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.inactive,
            );
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.hidden,
            );
        }
        await show();
        await tester.pumpAndSettle();
        expect(selection.currentState!.isAnimating, isFalse);
        reduced = false;
        visible = true;
        enabled = true;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
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
    testWidgets('подложка выбора живёт в фильтрах и сетке '
        '(${light ? 'днём' : 'ночью'})', (tester) async {
      final preview = Platform.environment['LIQUID_PREVIEW_PREFIX'];
      if (preview != null) {
        for (final entry in {
          'Ahem': 'assets/fonts/GolosText.ttf',
          'Unbounded': 'assets/fonts/Unbounded.ttf',
          'Golos Text': 'assets/fonts/GolosText.ttf',
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
        SettingsPatched(
          (current) => current.withAppearance(
            (a) => a.withEffect(LibraryEffect.liquidSelection, on: true),
          ),
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
          .widget<ChromeScrollView>(find.byType(ChromeScrollView))
          .controller;
      scroll.jumpTo(60);
      await frames(2);
      expect(
        state('grid-liquid').targetRect!.top,
        closeTo(beforeScroll.top - 60, 0.1),
      );
      expect(state('grid-liquid').isAnimating, isFalse);
      scroll.jumpTo(0);
      await frames(2);
      await tester.tap(find.text(l.tabInstalled));
      await frames(13);
      expect(state('shelf-liquid').isAnimating, isTrue);
      final palette = light ? EvaporatePalette.light : EvaporatePalette.dark;
      expect(
        DefaultTextStyle.of(tester.element(find.text(l.tabAll))).style.color,
        palette.onSelection,
      );
      await capture('filters');
      await frames(25);
      harness.nav.add(const SectionSelected(AppSection.settings));
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
      // Украшения гасятся набором «Выключено» — тем самым органом, что
      // видит человек. Отдельные флаги лежат под «Подробно» и при этом
      // сохраняются: набор трогает только общий выключатель.
      final off = find.descendant(
        of: find.byKey(const ValueKey('effects-preset')),
        matching: find.text(l.effectPresetOff),
      );
      expect(off, findsOneWidget);
      await capture('settings');
      await tester.tap(off);
      await frames(5);
      expect(harness.settings.state.appearance.libraryEffects, isFalse);
      expect(
        harness.settings.state.appearance.isOn(LibraryEffect.portal),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });
  }

  // Прямоугольник с NaN доезжал до `addRRect` и ронял отрисовку всего
  // кадра: `Rect.overlaps`, единственная проверка на его пути, NaN
  // пропускает — сравнения с ним всегда ложны, и ни один ранний выход
  // не срабатывает.
  testWidgets('вырожденное преобразование предка не роняет кадр', (
    tester,
  ) async {
    final target = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: LiquidSelection(
          targetKey: () => target,
          color: const Color(0xFF806040),
          radius: 18,
          child: Center(
            child: Transform(
              // Матрица без обратной: перевод в координаты подложки делит
              // на ноль, то есть даёт NaN.
              transform: Matrix4.zero(),
              child: SizedBox(key: target, width: 120, height: 40),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
