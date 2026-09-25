import 'dart:io';

import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/models/effect_quality.dart';
import 'package:evaporate/models/library_effect.dart';
import 'package:evaporate/ui/shell/hints_bar.dart';
import 'package:evaporate/ui/shell/navigation_rack.dart';
import 'package:evaporate/ui/shell/shell_glass.dart';
import 'package:evaporate/ui/shell/shell_layout.dart';
import 'package:evaporate/ui/shell/top_bar.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:evaporate/ui/widgets/glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/host_widget.dart';
import '../../support/test_app.dart';

/// Стекло полос каркаса: обойма, рейка и строка подсказок.
void main() {
  late Directory tmp;

  setUp(() async => tmp = await TestHarness.makeTempDir());
  tearDown(() => TestHarness.removeTempDir(tmp));

  Future<TestHarness> show(WidgetTester tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();
    return harness;
  }

  /// Фильтр стекла у каждой полосы — по её виджету.
  List<RenderBackdropFilter> filters(WidgetTester tester) => [
    for (final bar in [NavigationRack, TopBar, HintsBar])
      tester.renderObject<RenderBackdropFilter>(
        find.descendant(
          of: find.byType(bar),
          matching: find.byType(BackdropFilter),
        ),
      ),
  ];

  // Снимок фона берётся на первом стекле группы и достаётся остальным:
  // три полосы размывают фон один раз, а не трижды.
  testWidgets('три полосы читают один снимок фона', (tester) async {
    await show(tester);

    final bars = filters(tester);
    expect(bars.every((bar) => bar.enabled), isTrue);
    expect(bars.first.backdropKey, isNotNull);
    expect(bars.map((bar) => bar.backdropKey).toSet(), hasLength(1));
  });

  // Снимок берётся на первом стекле, и нарисованное после него в фон
  // соседа не попадает. Под рейкой лежат заливка и волна панели — значит,
  // рейка обязана рисоваться после панели, а обойма после рейки: иначе
  // рейка показала бы сквозь себя фон окна без самой панели.
  testWidgets('обойма рисуется после панели с рейкой', (tester) async {
    await show(tester);

    final [rack, top, hints] = filters(tester);
    final painted = <RenderObject>[];
    void visit(RenderObject object) => object.visitChildren((child) {
      if (child == rack || child == top || child == hints) painted.add(child);
      visit(child);
    });
    visit(tester.renderObject(find.byType(ShellLayout)));
    expect(painted, [top, hints, rack]);
  });

  testWidgets('без стекла полосы плотные, а фильтр выключен', (tester) async {
    final harness = await show(tester);

    harness.settings.add(
      SettingsPatched(
        (s) => s.withAppearance(
          (a) => a.withEffect(LibraryEffect.glass, on: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(filters(tester).any((bar) => bar.enabled), isFalse);
    final glass = GlassSurfaceTheme.of(tester.element(find.byType(TopBar)));
    final fill = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(ShellGlass).first,
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.gradient != null);
    final colors = (fill.gradient! as LinearGradient).colors;
    for (final color in colors) {
      expect(color.a, closeTo(glass.opaqueFillOpacity, 0.01));
    }
  });

  // Качество украшений — множитель размытия: экономное стекло размывает
  // слабее, а число берётся из темы схемы, не из виджета.
  testWidgets('качество украшений меняет размытие стекла', (tester) async {
    final harness = await show(tester);
    final glass = GlassSurfaceTheme.of(tester.element(find.byType(TopBar)));
    expect(
      filters(tester).first.filterConfig,
      GlassSurface.groupedFilterOf(glass),
    );

    harness.settings.add(
      SettingsPatched(
        (s) => s.withAppearance(
          (a) => a.copyWith(effectQuality: EffectQuality.eco),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      filters(tester).first.filterConfig,
      GlassSurface.groupedFilterOf(
        glass,
        blurScale: EffectQuality.eco.blurScale,
      ),
    );
  });

  // Флаг и качество знает одна полоса каркаса: обычное стекло карточек
  // блока не читает и годится где угодно.
  testWidgets('стекло полосы читает настройки, а обычное стекло — нет', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        const GlassSurface(
          radius: EvaporateTheme.radiusPanel,
          child: SizedBox.square(dimension: 40),
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      hostWidget(const ShellGlass(child: SizedBox.square(dimension: 40))),
    );
    expect(tester.takeException(), isNotNull);
  });
}
