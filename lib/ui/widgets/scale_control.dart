import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class ScaleControl extends StatelessWidget {
  const ScaleControl({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    required this.label,
  });
  final double value, min, max, step;
  final String label;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    void change(double next) => onChanged((next * 100).round() / 100);
    return Semantics(
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '${l.zoomOut}: $label',
            onPressed: value > min
                ? () => change((value - step).clamp(min, max))
                : null,
            icon: const Icon(Icons.remove, size: 18),
          ),
          Tooltip(
            message: l.resetScale,
            child: TextButton(
              onPressed: value == 1 ? null : () => onChanged(1),
              child: Text('${(value * 100).round()}%'),
            ),
          ),
          IconButton(
            tooltip: '${l.zoomIn}: $label',
            onPressed: value < max
                ? () => change((value + step).clamp(min, max))
                : null,
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }
}
