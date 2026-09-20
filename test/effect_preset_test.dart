import 'package:evaporate/models/app_settings.dart';
import 'package:evaporate/models/effect_preset.dart';
import 'package:evaporate/models/library_effect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = AppSettings(installDir: '/games');

  group('наборы украшений', () {
    test('свежие настройки отвечают набору «обычно»', () {
      // Иначе на свежей установке не горел бы ни один сегмент, и выбор
      // выглядел бы сломанным.
      expect(base.effectPreset, EffectPreset.standard);
      expect(
        AppSettings.fromJson(const {}, '/games').effectPreset,
        EffectPreset.standard,
      );
    });

    test('выключение не стирает собранный человеком набор', () {
      final mine = base
          .withEffect(LibraryEffect.particles, on: true)
          .withEffect(LibraryEffect.portal, on: false);

      final off = EffectPreset.off.applyTo(mine);

      expect(off.libraryEffects, isFalse);
      expect(off.effectPreset, EffectPreset.off);
      // Включив украшения обратно, человек получает свой набор, а не наш.
      expect(off.copyWith(libraryEffects: true), mine);
    });

    test('спокойный набор оставляет только то, что объясняет переезды', () {
      final calm = EffectPreset.calm.applyTo(base);

      expect(calm.libraryEffects, isTrue);
      expect(calm.isOn(LibraryEffect.interfaceAnimations), isTrue);
      expect(calm.isOn(LibraryEffect.coverBackdrop), isTrue);
      for (final off in [
        calm.isOn(LibraryEffect.particles),
        calm.isOn(LibraryEffect.waves),
        calm.isOn(LibraryEffect.foil),
        calm.isOn(LibraryEffect.cardTilt),
        calm.isOn(LibraryEffect.liquidDistortion),
        calm.isOn(LibraryEffect.liquidSelection),
        calm.isOn(LibraryEffect.ambient),
        calm.isOn(LibraryEffect.heroSweep),
        calm.isOn(LibraryEffect.shotsBackdrop),
        calm.isOn(LibraryEffect.drops),
        calm.isOn(LibraryEffect.portal),
      ]) {
        expect(off, isFalse);
      }
      expect(calm.effectPreset, EffectPreset.calm);
    });

    test('полный набор зажигает всё', () {
      final full = EffectPreset.full.applyTo(base);

      expect(full.effectPreset, EffectPreset.full);
      expect(full.isOn(LibraryEffect.particles), isTrue);
      expect(full.isOn(LibraryEffect.liquidDistortion), isTrue);
      expect(full.isOn(LibraryEffect.drops), isTrue);
    });

    test('наборы выстроены лестницей', () {
      // Спокойно ⊂ обычно ⊂ полностью: набор «поспокойнее» не должен
      // зажигать то, чего нет в наборе побогаче.
      final calm = EffectPreset.calm.applyTo(base);
      final standard = EffectPreset.standard.applyTo(base);
      final full = EffectPreset.full.applyTo(base);

      bool subset(AppSettings a, AppSettings b) => [
        (a.isOn(LibraryEffect.particles), b.isOn(LibraryEffect.particles)),
        (a.isOn(LibraryEffect.waves), b.isOn(LibraryEffect.waves)),
        (a.isOn(LibraryEffect.foil), b.isOn(LibraryEffect.foil)),
        (a.isOn(LibraryEffect.cardTilt), b.isOn(LibraryEffect.cardTilt)),
        (
          a.isOn(LibraryEffect.liquidDistortion),
          b.isOn(LibraryEffect.liquidDistortion),
        ),
        (
          a.isOn(LibraryEffect.liquidSelection),
          b.isOn(LibraryEffect.liquidSelection),
        ),
        (a.isOn(LibraryEffect.ambient), b.isOn(LibraryEffect.ambient)),
        (a.isOn(LibraryEffect.heroSweep), b.isOn(LibraryEffect.heroSweep)),
        (
          a.isOn(LibraryEffect.shotsBackdrop),
          b.isOn(LibraryEffect.shotsBackdrop),
        ),
        (
          a.isOn(LibraryEffect.coverBackdrop),
          b.isOn(LibraryEffect.coverBackdrop),
        ),
        (
          a.isOn(LibraryEffect.interfaceAnimations),
          b.isOn(LibraryEffect.interfaceAnimations),
        ),
        (a.isOn(LibraryEffect.drops), b.isOn(LibraryEffect.drops)),
        (a.isOn(LibraryEffect.portal), b.isOn(LibraryEffect.portal)),
      ].every((pair) => !pair.$1 || pair.$2);

      expect(subset(calm, standard), isTrue);
      expect(subset(standard, full), isTrue);
    });

    test('свой набор не притворяется готовым', () {
      final custom = EffectPreset.calm
          .applyTo(base)
          .withEffect(LibraryEffect.portal, on: true);

      expect(custom.effectPreset, isNull);
    });

    test('рамка выбора наборам не подчиняется', () {
      // Она показывает место в сетке, а не украшает её, и живёт мимо
      // общего выключателя.
      for (final preset in EffectPreset.values) {
        expect(
          preset
              .applyTo(base.withEffect(LibraryEffect.selectionFrame, on: true))
              .isOn(LibraryEffect.selectionFrame),
          isTrue,
          reason: 'набор ${preset.name} погасил рамку',
        );
        expect(
          preset
              .applyTo(base.withEffect(LibraryEffect.selectionFrame, on: false))
              .isOn(LibraryEffect.selectionFrame),
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
