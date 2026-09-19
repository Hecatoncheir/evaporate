import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme.dart';

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
    text: _textFor(widget.value),
  );
  final _focus = FocusNode();

  static String _textFor(int value) => value > 0 ? '$value' : '';

  @override
  void initState() {
    super.initState();
    // Фиксируем на любой потере фокуса, а не только по Enter и щелчку
    // мимо: страница настроек уводит фокус стрелками, и набранное иначе
    // оставалось бы в поле, никуда не записавшись.
    _focus.addListener(() {
      if (!_focus.hasFocus) _submit(_controller.text);
    });
  }

  @override
  void didUpdateWidget(SpeedField old) {
    super.didUpdateWidget(old);
    // Значение могли поменять и не здесь. Пока человек набирает, его не
    // трогаем; иначе поле показывало бы прежнее и записало бы его поверх
    // нового при следующем уходе фокуса.
    if (widget.value != old.value && !_focus.hasFocus) {
      _controller.text = _textFor(widget.value);
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _submit(String raw) {
    final parsed = int.tryParse(raw.trim()) ?? 0;
    final value = parsed > 0 ? parsed : 0;
    if (value != widget.value) widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: EvaporateLayout.settingLabelWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(widget.label, style: context.text.body),
            ),
          ),
          SizedBox(
            width: 130,
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                isDense: true,
                hintText: L.of(context).unlimitedShort,
                suffixText: widget.unit ?? L.of(context).kilobytesPerSecond,
              ),
              onSubmitted: _submit,
              // Щелчок мимо снимает фокус, а запись делает его слушатель.
              onTapOutside: (_) => _focus.unfocus(),
            ),
          ),
          if (widget.hint != null)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 12, top: 12),
                child: Text(widget.hint!, style: context.text.captionMuted),
              ),
            ),
        ],
      ),
    );
  }
}
