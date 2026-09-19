import 'package:flutter/material.dart';

import '../theme.dart';

/// Настройка «один из нескольких»: подпись слева, сегменты справа.
///
/// Три выбора — язык, оформление, окно при запуске — были выписаны
/// одинаково по всем строкам, кроме сегментов. Сегменты, а не выпадающий
/// список: вариантов два-три, и прятать их за нажатием незачем.
class SegmentedSetting<T> extends StatelessWidget {
  const SegmentedSetting({
    super.key,
    required this.label,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<ButtonSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: EvaporateLayout.settingLabelWidth,
          child: Text(label, style: context.text.body),
        ),
        Expanded(
          child: SegmentedButton<T>(
            segments: segments,
            selected: {selected},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
        ),
      ],
    );
  }
}
