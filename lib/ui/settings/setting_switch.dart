import 'package:flutter/material.dart';

/// Переключатель настройки: подпись, необязательное пояснение и тумблер.
///
/// `SwitchListTile` с нулевыми полями был выписан в настройках десять раз,
/// и у каждого — те же поля и те же стили подписей. Кегли подписей задаёт
/// плотная тема списков, поэтому здесь их нет.
class SettingSwitch extends StatelessWidget {
  const SettingSwitch({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.note,
  });

  final String title;
  final bool value;

  /// null — переключатель погашен.
  final ValueChanged<bool>? onChanged;

  final String? note;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: note == null ? null : Text(note!),
    );
  }
}
