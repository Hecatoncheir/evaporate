import 'package:evaporate/models/app_settings.dart';
import 'package:evaporate/models/effect_preset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = AppSettings(installDir: '/games');

  group('наборы украшений', () {
    test('свежие настройки отвечают набору «обычно»', () {
      // Иначе на свежей установке не горел бы ни один сегмент, и выбор
      // выглядел бы сломанным.
      expect(base.effectPreset, EffectPreset.standard);
      expect(
        AppSettings.fromJson({}, '/games').effectPreset,
        EffectPreset.standard,
      );
    });

    test('выключение не стирает собранный человеком набор', () {
      final mine = base.copyWith(particlesEnabled: true, portalEnabled: false);

      final off = EffectPreset.off.applyTo(mine);

      expect(off.libraryEffects, isFalse);
      expect(off.effectPreset, EffectPreset.off);
      // Включив украшения обратно, человек получает свой набор, а не наш.
      expect(off.copyWith(libraryEffects: true), mine);
    });

    test('спокойный набор оставляет только то, что объясняет переезды', () {
      final calm = EffectPreset.calm.applyTo(base);

      expect(calm.libraryEffects, isTrue);
      expect(calm.interfaceAnimationsEnabled, isTrue);
      expect(calm.coverBackdropEnabled, isTrue);
      for (final off in [
        calm.particlesEnabled,
        calm.wavesEnabled,
        calm.foilEnabled,
        calm.cardTiltEnabled,
        calm.liquidDistortionEnabled,
        calm.liquidSelectionEnabled,
        calm.ambientEnabled,
        calm.heroSweepEnabled,
        calm.dropsEnabled,
        calm.portalEnabled,
      ]) {
        expect(off, isFalse);
      }
      expect(calm.effectPreset, EffectPreset.calm);
    });

    test('полный набор зажигает всё', () {
      final full = EffectPreset.full.applyTo(base);

      expect(full.effectPreset, EffectPreset.full);
      expect(full.particlesEnabled, isTrue);
      expect(full.liquidDistortionEnabled, isTrue);
      expect(full.dropsEnabled, isTrue);
    });

    test('наборы выстроены лестницей', () {
      // Спокойно ⊂ обычно ⊂ полностью: набор «поспокойнее» не должен
      // зажигать то, чего нет в наборе побогаче.
      final calm = EffectPreset.calm.applyTo(base);
      final standard = EffectPreset.standard.applyTo(base);
      final full = EffectPreset.full.applyTo(base);

      bool subset(AppSettings a, AppSettings b) => [
        (a.particlesEnabled, b.particlesEnabled),
        (a.wavesEnabled, b.wavesEnabled),
        (a.foilEnabled, b.foilEnabled),
        (a.cardTiltEnabled, b.cardTiltEnabled),
        (a.liquidDistortionEnabled, b.liquidDistortionEnabled),
        (a.liquidSelectionEnabled, b.liquidSelectionEnabled),
        (a.ambientEnabled, b.ambientEnabled),
        (a.heroSweepEnabled, b.heroSweepEnabled),
        (a.coverBackdropEnabled, b.coverBackdropEnabled),
        (a.interfaceAnimationsEnabled, b.interfaceAnimationsEnabled),
        (a.dropsEnabled, b.dropsEnabled),
        (a.portalEnabled, b.portalEnabled),
      ].every((pair) => !pair.$1 || pair.$2);

      expect(subset(calm, standard), isTrue);
      expect(subset(standard, full), isTrue);
    });

    test('свой набор не притворяется готовым', () {
      final custom = EffectPreset.calm
          .applyTo(base)
          .copyWith(portalEnabled: true);

      expect(custom.effectPreset, isNull);
    });

    test('рамка выбора наборам не подчиняется', () {
      // Она показывает место в сетке, а не украшает её, и живёт мимо
      // общего выключателя.
      for (final preset in EffectPreset.values) {
        expect(
          preset
              .applyTo(base.copyWith(selectionFrameEnabled: true))
              .selectionFrameEnabled,
          isTrue,
          reason: 'набор ${preset.name} погасил рамку',
        );
        expect(
          preset
              .applyTo(base.copyWith(selectionFrameEnabled: false))
              .selectionFrameEnabled,
          isFalse,
          reason: 'набор ${preset.name} зажёг рамку',
        );
      }
    });

    test('набор не трогает ничего, кроме украшений', () {
      final settings = base.copyWith(
        interfaceScale: 1.2,
        libraryScale: 1.5,
        maxConcurrent: 8,
        locale: 'en',
      );

      for (final preset in EffectPreset.values) {
        final applied = preset.applyTo(settings);
        expect(applied.interfaceScale, 1.2);
        expect(applied.libraryScale, 1.5);
        expect(applied.maxConcurrent, 8);
        expect(applied.locale, 'en');
      }
    });
  });
}
