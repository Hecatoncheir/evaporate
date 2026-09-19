import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/app_settings.dart';
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
    void update(AppSettings next) => store.add(SettingsChanged(next));

    return ExpansionTile(
      key: const ValueKey('effects-details'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: Text(l.effectsDetails, style: context.text.bodyStrong),
      children: [
        SettingSwitch(
          key: const ValueKey('effects-master-toggle'),
          value: settings.libraryEffects,
          onChanged: (value) =>
              update(settings.copyWith(libraryEffects: value)),
          title: l.libraryEffectsEnable,
        ),
        for (final effect in _effects(l))
          SettingSwitch(
            key: ValueKey('effects-${effect.id}-toggle'),
            title: effect.title,
            note: effect.note,
            value: effect.value(settings),
            // Рамка выбора живёт мимо общего выключателя: она показывает
            // место в сетке, а не украшает её, и зажигается по прямой
            // просьбе.
            onChanged: settings.libraryEffects || effect.independent
                ? (value) => update(effect.apply(settings, on: value))
                : null,
          ),
      ],
    );
  }

  /// Украшения одним списком: имя ключа, подпись, чтение и запись флага.
  ///
  /// Списком, а не тринадцатью выписанными вручную переключателями: они
  /// различались только названием флага, и каждый новый добавлял двенадцать
  /// строк копии, в которых легко перепутать поле.
  static List<_Effect> _effects(L l) => [
    _Effect(
      id: 'particles',
      title: l.effectParticles,
      value: (s) => s.particlesEnabled,
      apply: (s, {required on}) => s.copyWith(particlesEnabled: on),
    ),
    _Effect(
      id: 'waves',
      title: l.effectWaves,
      value: (s) => s.wavesEnabled,
      apply: (s, {required on}) => s.copyWith(wavesEnabled: on),
    ),
    _Effect(
      id: 'foil',
      title: l.effectFoil,
      value: (s) => s.foilEnabled,
      apply: (s, {required on}) => s.copyWith(foilEnabled: on),
    ),
    _Effect(
      id: 'cardTilt',
      title: l.effectCardTilt,
      value: (s) => s.cardTiltEnabled,
      apply: (s, {required on}) => s.copyWith(cardTiltEnabled: on),
    ),
    _Effect(
      id: 'liquidDistortion',
      title: l.effectLiquidDistortion,
      value: (s) => s.liquidDistortionEnabled,
      apply: (s, {required on}) => s.copyWith(liquidDistortionEnabled: on),
    ),
    _Effect(
      id: 'liquidSelection',
      title: l.effectLiquidSelection,
      value: (s) => s.liquidSelectionEnabled,
      apply: (s, {required on}) => s.copyWith(liquidSelectionEnabled: on),
    ),
    _Effect(
      id: 'ambient',
      title: l.effectAmbient,
      note: l.effectAmbientNote,
      value: (s) => s.ambientEnabled,
      apply: (s, {required on}) => s.copyWith(ambientEnabled: on),
    ),
    _Effect(
      id: 'heroSweep',
      title: l.effectHeroSweep,
      value: (s) => s.heroSweepEnabled,
      apply: (s, {required on}) => s.copyWith(heroSweepEnabled: on),
    ),
    _Effect(
      id: 'shotsBackdrop',
      title: l.effectShotsBackdrop,
      note: l.effectShotsBackdropNote,
      value: (s) => s.shotsBackdropEnabled,
      apply: (s, {required on}) => s.copyWith(shotsBackdropEnabled: on),
    ),
    _Effect(
      id: 'coverBackdrop',
      title: l.effectCoverBackdrop,
      value: (s) => s.coverBackdropEnabled,
      apply: (s, {required on}) => s.copyWith(coverBackdropEnabled: on),
    ),
    _Effect(
      id: 'drops',
      title: l.effectDrops,
      note: l.effectDropsNote,
      value: (s) => s.dropsEnabled,
      apply: (s, {required on}) => s.copyWith(dropsEnabled: on),
    ),
    _Effect(
      id: 'portal',
      title: l.effectPortal,
      note: l.effectPortalNote,
      value: (s) => s.portalEnabled,
      apply: (s, {required on}) => s.copyWith(portalEnabled: on),
    ),
    _Effect(
      id: 'selectionFrame',
      title: l.effectSelectionFrame,
      note: l.effectSelectionFrameNote,
      independent: true,
      value: (s) => s.selectionFrameEnabled,
      apply: (s, {required on}) => s.copyWith(selectionFrameEnabled: on),
    ),
    _Effect(
      id: 'interfaceAnimations',
      title: l.effectInterfaceAnimations,
      value: (s) => s.interfaceAnimationsEnabled,
      apply: (s, {required on}) => s.copyWith(interfaceAnimationsEnabled: on),
    ),
  ];
}

class _Effect {
  const _Effect({
    required this.id,
    required this.title,
    required this.value,
    required this.apply,
    this.note,
    this.independent = false,
  });

  /// Кусок ключа виджета: `effects-<id>-toggle`. По нему переключатель
  /// находят тесты, поэтому имена здесь менять нельзя просто так.
  final String id;
  final String title;
  final String? note;
  final bool Function(AppSettings) value;
  final AppSettings Function(AppSettings settings, {required bool on}) apply;

  /// Не заперт общим выключателем украшений.
  final bool independent;
}
