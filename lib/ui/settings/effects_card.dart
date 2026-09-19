import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/app_settings.dart';
import '../../models/effect_preset.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Живая библиотека: набор одним выбором, отдельные украшения — под
/// «Подробно».
///
/// Тринадцать переключателей подряд человек не выбирает, а пролистывает, и
/// половина подписей («Liquid Distortion», «Волны (wave)») ничего не
/// говорит тому, кто не читал код. Наверху теперь выбор из трёх наборов, а
/// флаги остались все: у украшений разная цена и разный вкус, и один общий
/// выключатель означал бы «или всё, или ничего».
///
/// Набор — не новое состояние, а раскладка тех же флагов
/// ([EffectPreset.applyTo]). Собрал человек своё в «Подробно» — ни один
/// сегмент не горит, и это честнее, чем подсветить ближайший.
class LibraryEffectsCard extends StatelessWidget {
  const LibraryEffectsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SettingsBloc>();
    final settings = store.state;
    final l = L.of(context);

    void update(AppSettings next) => store.add(SettingsChanged(next));

    return SectionCard(
      key: const ValueKey('living-library-settings'),
      title: l.libraryEffects,
      icon: Icons.auto_awesome_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _presets(l, settings, update),
          const SizedBox(height: 10),
          Text(
            settings.effectPreset == null
                ? l.effectPresetCustom
                : l.libraryEffectsNote,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: context.colors.textSecondary,
            ),
          ),
          _details(l, settings, update),
        ],
      ),
    );
  }

  /// Четыре набора: выключено, спокойно, обычно, полностью.
  Widget _presets(
    L l,
    AppSettings settings,
    void Function(AppSettings) update,
  ) => SegmentedButton<EffectPreset>(
    key: const ValueKey('effects-preset'),
    segments: [
      ButtonSegment(value: EffectPreset.off, label: Text(l.effectPresetOff)),
      ButtonSegment(value: EffectPreset.calm, label: Text(l.effectPresetCalm)),
      ButtonSegment(
        value: EffectPreset.standard,
        label: Text(l.effectPresetStandard),
      ),
      ButtonSegment(value: EffectPreset.full, label: Text(l.effectPresetFull)),
    ],
    // Пустой выбор разрешён ради своего набора: сегменты показывают,
    // что выбрано, а не куда ткнуть наугад.
    emptySelectionAllowed: true,
    showSelectedIcon: false,
    selected: {?settings.effectPreset},
    // Нажатие на горящий сегмент снимает выбор и отдаёт пустое множество —
    // это не новый набор, а отсутствие действия.
    onSelectionChanged: (selection) {
      if (selection.isEmpty) return;
      update(selection.first.applyTo(settings));
    },
    style: const ButtonStyle(
      textStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12.5, fontFamily: EvaporateTheme.fontFamily),
      ),
    ),
  );

  /// «Подробно»: общий выключатель и по галочке на каждое украшение.
  Widget _details(
    L l,
    AppSettings settings,
    void Function(AppSettings) update,
  ) => ExpansionTile(
    key: const ValueKey('effects-details'),
    tilePadding: EdgeInsets.zero,
    childrenPadding: EdgeInsets.zero,
    title: Text(
      l.effectsDetails,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
    children: [
      SwitchListTile(
        key: const ValueKey('effects-master-toggle'),
        value: settings.libraryEffects,
        onChanged: (value) => update(settings.copyWith(libraryEffects: value)),
        contentPadding: EdgeInsets.zero,
        title: Text(l.libraryEffectsEnable),
      ),
      for (final effect in _effects(l))
        SwitchListTile(
          key: ValueKey('effects-${effect.id}-toggle'),
          contentPadding: EdgeInsets.zero,
          title: Text(effect.title),
          subtitle: effect.note == null
              ? null
              : Text(effect.note!, style: const TextStyle(fontSize: 12)),
          value: effect.value(settings),
          // Рамка выбора живёт мимо общего выключателя: она показывает
          // место в сетке, а не украшает её, и зажигается по прямой
          // просьбе.
          onChanged: settings.libraryEffects || effect.independent
              ? (value) => update(effect.apply(settings, value))
              : null,
        ),
    ],
  );

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
      apply: (s, v) => s.copyWith(particlesEnabled: v),
    ),
    _Effect(
      id: 'waves',
      title: l.effectWaves,
      value: (s) => s.wavesEnabled,
      apply: (s, v) => s.copyWith(wavesEnabled: v),
    ),
    _Effect(
      id: 'foil',
      title: l.effectFoil,
      value: (s) => s.foilEnabled,
      apply: (s, v) => s.copyWith(foilEnabled: v),
    ),
    _Effect(
      id: 'cardTilt',
      title: l.effectCardTilt,
      value: (s) => s.cardTiltEnabled,
      apply: (s, v) => s.copyWith(cardTiltEnabled: v),
    ),
    _Effect(
      id: 'liquidDistortion',
      title: l.effectLiquidDistortion,
      value: (s) => s.liquidDistortionEnabled,
      apply: (s, v) => s.copyWith(liquidDistortionEnabled: v),
    ),
    _Effect(
      id: 'liquidSelection',
      title: l.effectLiquidSelection,
      value: (s) => s.liquidSelectionEnabled,
      apply: (s, v) => s.copyWith(liquidSelectionEnabled: v),
    ),
    _Effect(
      id: 'ambient',
      title: l.effectAmbient,
      note: l.effectAmbientNote,
      value: (s) => s.ambientEnabled,
      apply: (s, v) => s.copyWith(ambientEnabled: v),
    ),
    _Effect(
      id: 'heroSweep',
      title: l.effectHeroSweep,
      value: (s) => s.heroSweepEnabled,
      apply: (s, v) => s.copyWith(heroSweepEnabled: v),
    ),
    _Effect(
      id: 'shotsBackdrop',
      title: l.effectShotsBackdrop,
      note: l.effectShotsBackdropNote,
      value: (s) => s.shotsBackdropEnabled,
      apply: (s, v) => s.copyWith(shotsBackdropEnabled: v),
    ),
    _Effect(
      id: 'coverBackdrop',
      title: l.effectCoverBackdrop,
      value: (s) => s.coverBackdropEnabled,
      apply: (s, v) => s.copyWith(coverBackdropEnabled: v),
    ),
    _Effect(
      id: 'drops',
      title: l.effectDrops,
      note: l.effectDropsNote,
      value: (s) => s.dropsEnabled,
      apply: (s, v) => s.copyWith(dropsEnabled: v),
    ),
    _Effect(
      id: 'portal',
      title: l.effectPortal,
      note: l.effectPortalNote,
      value: (s) => s.portalEnabled,
      apply: (s, v) => s.copyWith(portalEnabled: v),
    ),
    _Effect(
      id: 'selectionFrame',
      title: l.effectSelectionFrame,
      note: l.effectSelectionFrameNote,
      independent: true,
      value: (s) => s.selectionFrameEnabled,
      apply: (s, v) => s.copyWith(selectionFrameEnabled: v),
    ),
    _Effect(
      id: 'interfaceAnimations',
      title: l.effectInterfaceAnimations,
      value: (s) => s.interfaceAnimationsEnabled,
      apply: (s, v) => s.copyWith(interfaceAnimationsEnabled: v),
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
  final AppSettings Function(AppSettings, bool) apply;

  /// Не заперт общим выключателем украшений.
  final bool independent;
}
