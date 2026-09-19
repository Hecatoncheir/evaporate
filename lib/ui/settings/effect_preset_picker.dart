import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/app_settings.dart';
import '../../models/effect_preset.dart';

/// Четыре набора украшений: выключено, спокойно, обычно, полностью.
class EffectPresetPicker extends StatelessWidget {
  const EffectPresetPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SettingsBloc>();
    final settings = store.state;
    final l = L.of(context);
    void update(AppSettings next) => store.add(SettingsChanged(next));

    return SegmentedButton<EffectPreset>(
      key: const ValueKey('effects-preset'),
      segments: [
        ButtonSegment(value: EffectPreset.off, label: Text(l.effectPresetOff)),
        ButtonSegment(
          value: EffectPreset.calm,
          label: Text(l.effectPresetCalm),
        ),
        ButtonSegment(
          value: EffectPreset.standard,
          label: Text(l.effectPresetStandard),
        ),
        ButtonSegment(
          value: EffectPreset.full,
          label: Text(l.effectPresetFull),
        ),
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
    );
  }
}
