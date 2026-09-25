import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/settings/settings_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/effect_preset.dart';
import '../../theme.dart';
import '../../widgets/section_card.dart';
import '../effect_details.dart';
import '../effect_preset_picker.dart';
import '../effect_quality_picker.dart';
import '../setting_note.dart';

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
    final settings = context.watch<SettingsBloc>().state;
    final l = L.of(context);

    return SectionCard(
      key: const ValueKey('living-library-settings'),
      title: l.libraryEffects,
      icon: Icons.auto_awesome_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EffectPresetPicker(),
          const SizedBox(height: EvaporateSpacing.cluster),
          SettingNote(
            settings.appearance.effectPreset == null
                ? l.effectPresetCustom
                : l.libraryEffectsNote,
          ),
          const SizedBox(height: EvaporateSpacing.cluster),
          const EffectQualityPicker(),
          const EffectDetails(),
        ],
      ),
    );
  }
}
