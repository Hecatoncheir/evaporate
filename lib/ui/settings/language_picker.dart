import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'segmented_setting.dart';

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
    // У сегмента не бывает значения null, поэтому «как в системе» внутри
    // выбора — пустая строка, а наружу снова null.
    return SegmentedSetting<String>(
      label: l.language,
      segments: [
        ButtonSegment(value: '', label: Text(l.languageSystem)),
        ButtonSegment(value: 'ru', label: Text(l.languageRussian)),
        ButtonSegment(value: 'en', label: Text(l.languageEnglish)),
      ],
      selected: value ?? '',
      onChanged: (code) => onChanged(code.isEmpty ? null : code),
    );
  }
}
