import 'dart:io';

import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/models/app_section.dart';
import 'package:evaporate/models/effect_preset.dart';
import 'package:evaporate/models/effect_quality.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

/// Качество украшений — выбор рядом с набором, но не внутри него.
void main() {
  final l = LRu();

  late Directory tmp;
  setUp(() async => tmp = await TestHarness.makeTempDir());
  tearDown(() => TestHarness.removeTempDir(tmp));

  Future<TestHarness> openSettings(WidgetTester tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    await harness.pump(tester);
    harness.nav.add(const SectionSelected(AppSection.settings));
    await tester.pumpAndSettle();
    return harness;
  }

  Finder segment(String label) => find.descendant(
    of: find.byKey(const ValueKey('effects-quality')),
    matching: find.text(label),
  );

  testWidgets('качество выбирается в живой библиотеке и не трогает набор', (
    tester,
  ) async {
    final harness = await openSettings(tester);
    final preset = harness.settings.state.appearance.effectPreset;
    expect(harness.settings.state.appearance.effectQuality, EffectQuality.full);

    await tester.ensureVisible(segment(l.effectQualityEco));
    await tester.pumpAndSettle();
    await tester.tap(segment(l.effectQualityEco));
    await tester.pumpAndSettle();

    expect(harness.settings.state.appearance.effectQuality, EffectQuality.eco);
    // Набор — про то, что горит, качество — про цену: одно не сбивает
    // другое, и «Обычно» остаётся «Обычно».
    expect(harness.settings.state.appearance.effectPreset, preset);
    expect(preset, EffectPreset.standard);
  });

  test('ступени качества дешевле и дороже полного', () {
    expect(EffectQuality.eco.factor, lessThan(EffectQuality.full.factor));
    expect(EffectQuality.max.factor, greaterThan(EffectQuality.full.factor));
    expect(EffectQuality.full.factor, 1);
    expect(EffectQuality.full.blurScale, 1);
    // Размытие дорожает с радиусом быстрее плотности — и растёт медленнее.
    expect(EffectQuality.max.blurScale, lessThan(EffectQuality.max.factor));
  });
}
