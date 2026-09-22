import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/app_settings.dart';
import '../../models/library_effect.dart';
import '../theme.dart';
import 'setting_switch.dart';

/// «Подробно»: общий выключатель и по галочке на каждое украшение.
class EffectDetails extends StatelessWidget {
  const EffectDetails({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SettingsBloc>();
    final settings = store.state;
    final l = L.of(context);
    void update(AppSettings Function(AppSettings current) patch) =>
        store.add(SettingsPatched(patch));

    return ExpansionTile(
      key: const ValueKey('effects-details'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: Text(l.effectsDetails, style: context.text.bodyStrong),
      children: [
        SettingSwitch(
          key: const ValueKey('effects-master-toggle'),
          value: settings.appearance.libraryEffects,
          onChanged: (value) => update(
            (current) => current.withAppearance(
              (a) => a.copyWith(libraryEffects: value),
            ),
          ),
          title: l.libraryEffectsEnable,
        ),
        // Переключатели идут прямо по перечислимой: порядок объявления —
        // порядок в списке, а `name` — ключ виджета. Прежде каждый был
        // выписан вручную вместе с чтением и записью своего флага, и
        // новое украшение добавляло дюжину строк копии.
        for (final effect in LibraryEffect.values)
          SettingSwitch(
            key: ValueKey('effects-${effect.name}-toggle'),
            title: _title(l, effect),
            note: _note(l, effect),
            value: settings.appearance.isOn(effect),
            // Рамка выбора живёт мимо общего выключателя: она показывает
            // место в сетке, а не украшает её, и зажигается по прямой
            // просьбе.
            onChanged: settings.appearance.libraryEffects || effect.independent
                ? (value) => update(
                    (current) => current.withAppearance(
                      (a) => a.withEffect(effect, on: value),
                    ),
                  )
                : null,
          ),
      ],
    );
  }

  static String _title(L l, LibraryEffect effect) => switch (effect) {
    LibraryEffect.particles => l.effectParticles,
    LibraryEffect.waves => l.effectWaves,
    LibraryEffect.foil => l.effectFoil,
    LibraryEffect.cardTilt => l.effectCardTilt,
    LibraryEffect.liquidDistortion => l.effectLiquidDistortion,
    LibraryEffect.liquidSelection => l.effectLiquidSelection,
    LibraryEffect.ambient => l.effectAmbient,
    LibraryEffect.heroSweep => l.effectHeroSweep,
    LibraryEffect.shotsBackdrop => l.effectShotsBackdrop,
    LibraryEffect.coverBackdrop => l.effectCoverBackdrop,
    LibraryEffect.drops => l.effectDrops,
    LibraryEffect.portal => l.effectPortal,
    LibraryEffect.selectionFrame => l.effectSelectionFrame,
    LibraryEffect.interfaceAnimations => l.effectInterfaceAnimations,
  };

  /// Пояснение под подписью — там, где одного названия мало: цена у
  /// эффекта своя или он есть не у каждой игры.
  static String? _note(L l, LibraryEffect effect) => switch (effect) {
    LibraryEffect.ambient => l.effectAmbientNote,
    LibraryEffect.shotsBackdrop => l.effectShotsBackdropNote,
    LibraryEffect.drops => l.effectDropsNote,
    LibraryEffect.portal => l.effectPortalNote,
    LibraryEffect.selectionFrame => l.effectSelectionFrameNote,
    _ => null,
  };
}
