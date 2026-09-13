import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme.dart';

/// Выбор оформления.
///
/// Три кнопки, а не переключатель: «как в системе» — не середина между
/// светлой и тёмной, а отдельный вариант, и выпадающим списком его пришлось
/// бы искать.
/// Поле скорости в килобайтах в секунду. Пустое значение и ноль означают
/// «без ограничения» — так понятнее, чем отдельная галочка рядом с числом.
class SpeedField extends StatefulWidget {
  const SpeedField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.unit,
  });

  final String label;
  final int value;
  final String? hint;

  /// Единица измерения. По умолчанию килобайты в секунду —
  /// поле задумывалось для скорости, но порог раздачи считается
  /// в сотых долях.
  final String? unit;
  final ValueChanged<int> onChanged;

  @override
  State<SpeedField> createState() => _SpeedFieldState();
}

class _SpeedFieldState extends State<SpeedField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value > 0 ? '${widget.value}' : '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String raw) {
    final parsed = int.tryParse(raw.trim()) ?? 0;
    widget.onChanged(parsed > 0 ? parsed : 0);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 220,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(widget.label, style: const TextStyle(fontSize: 13)),
            ),
          ),
          SizedBox(
            width: 130,
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                isDense: true,
                hintText: L.of(context).unlimitedShort,
                suffixText: widget.unit ?? L.of(context).kilobytesPerSecond,
              ),
              onSubmitted: _submit,
              onTapOutside: (_) => _submit(_controller.text),
            ),
          ),
          if (widget.hint != null)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 12, top: 12),
                child: Text(
                  widget.hint!,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
