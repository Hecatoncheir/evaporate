import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/window_start_mode.dart';
import '../theme.dart';

/// Выбор языка интерфейса.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// null — брать язык системы.
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Row(
      children: [
        SizedBox(
          width: EvaporateLayout.settingLabelWidth,
          child: Text(l.language, style: context.text.body),
        ),
        Expanded(
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: '', label: Text(l.languageSystem)),
              ButtonSegment(value: 'ru', label: Text(l.languageRussian)),
              ButtonSegment(value: 'en', label: Text(l.languageEnglish)),
            ],
            selected: {value ?? ''},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              final code = selection.first;
              onChanged(code.isEmpty ? null : code);
            },
          ),
        ),
      ],
    );
  }
}

/// Каким открывать окно при запуске.
class WindowStartPicker extends StatelessWidget {
  const WindowStartPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final WindowStartMode value;
  final ValueChanged<WindowStartMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: EvaporateLayout.settingLabelWidth,
          child: Text(L.of(context).windowOnStart, style: context.text.body),
        ),
        Expanded(
          child: SegmentedButton<WindowStartMode>(
            segments: [
              ButtonSegment(
                value: WindowStartMode.remembered,
                icon: const Icon(Icons.crop_din, size: 17),
                label: Text(L.of(context).windowRemembered),
              ),
              ButtonSegment(
                value: WindowStartMode.maximized,
                icon: const Icon(Icons.fullscreen, size: 17),
                label: Text(L.of(context).windowMaximized),
              ),
              ButtonSegment(
                value: WindowStartMode.minimized,
                icon: const Icon(Icons.expand_more, size: 17),
                label: Text(L.of(context).windowMinimized),
              ),
            ],
            selected: {value},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
        ),
      ],
    );
  }
}

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
    return Row(
      children: [
        SizedBox(
          width: EvaporateLayout.settingLabelWidth,
          child: Text(L.of(context).appearance, style: context.text.body),
        ),
        Expanded(
          child: SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                icon: const Icon(Icons.brightness_auto_outlined, size: 17),
                label: Text(L.of(context).themeSystem),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: const Icon(Icons.light_mode_outlined, size: 17),
                label: Text(L.of(context).themeLight),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: const Icon(Icons.dark_mode_outlined, size: 17),
                label: Text(L.of(context).themeDark),
              ),
            ],
            selected: {value},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
        ),
      ],
    );
  }
}
