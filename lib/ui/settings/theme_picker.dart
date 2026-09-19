import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'segmented_setting.dart';

/// Выбор оформления.
///
/// Три кнопки, а не переключатель: «как в системе» — не середина между
/// светлой и тёмной, а отдельный вариант, и выпадающим списком его пришлось
/// бы искать.
class ThemePicker extends StatelessWidget {
  const ThemePicker({super.key, required this.value, required this.onChanged});

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return SegmentedSetting<ThemeMode>(
      label: l.appearance,
      segments: [
        ButtonSegment(
          value: ThemeMode.system,
          icon: const Icon(Icons.brightness_auto_outlined, size: 17),
          label: Text(l.themeSystem),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          icon: const Icon(Icons.light_mode_outlined, size: 17),
          label: Text(l.themeLight),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          icon: const Icon(Icons.dark_mode_outlined, size: 17),
          label: Text(l.themeDark),
        ),
      ],
      selected: value,
      onChanged: onChanged,
    );
  }
}
