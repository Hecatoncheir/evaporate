import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/app_theme_mode.dart';
import 'segmented_setting.dart';

/// Выбор оформления.
///
/// Три кнопки, а не переключатель: «как в системе» — не середина между
/// светлой и тёмной, а отдельный вариант, и выпадающим списком его пришлось
/// бы искать.
class ThemePicker extends StatelessWidget {
  const ThemePicker({super.key, required this.value, required this.onChanged});

  final AppThemeMode value;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return SegmentedSetting<AppThemeMode>(
      label: l.appearance,
      segments: [
        ButtonSegment(
          value: AppThemeMode.system,
          icon: const Icon(Icons.brightness_auto_outlined),
          label: Text(l.themeSystem),
        ),
        ButtonSegment(
          value: AppThemeMode.light,
          icon: const Icon(Icons.light_mode_outlined),
          label: Text(l.themeLight),
        ),
        ButtonSegment(
          value: AppThemeMode.dark,
          icon: const Icon(Icons.dark_mode_outlined),
          label: Text(l.themeDark),
        ),
      ],
      selected: value,
      onChanged: onChanged,
    );
  }
}
