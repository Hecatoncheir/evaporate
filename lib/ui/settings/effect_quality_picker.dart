import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/effect_quality.dart';
import 'segmented_setting.dart';

/// Качество украшений: эко, полное, наибольшее.
///
/// Рядом с набором, но не внутри него: набор решает, что горит, а
/// качество — сколько горящее стоит кадру. Выбрав «Полностью» на слабой
/// машине, человек не обязан гасить украшения по одному — хватит «Эко».
class EffectQualityPicker extends StatelessWidget {
  const EffectQualityPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final quality = context.select<SettingsBloc, EffectQuality>(
      (bloc) => bloc.state.appearance.effectQuality,
    );
    final l = L.of(context);
    return SegmentedSetting<EffectQuality>(
      key: const ValueKey('effects-quality'),
      label: l.effectQuality,
      segments: [
        ButtonSegment(
          value: EffectQuality.eco,
          label: Text(l.effectQualityEco),
        ),
        ButtonSegment(
          value: EffectQuality.full,
          label: Text(l.effectQualityFull),
        ),
        ButtonSegment(
          value: EffectQuality.max,
          label: Text(l.effectQualityMax),
        ),
      ],
      selected: quality,
      onChanged: (value) => context.read<SettingsBloc>().add(
        SettingsPatched(
          (s) => s.withAppearance((a) => a.copyWith(effectQuality: value)),
        ),
      ),
    );
  }
}
