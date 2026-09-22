import 'package:flutter/material.dart';

import '../theme.dart';

/// Плашка в цвете своего смысла: надпись цветом и он же заливкой, только
/// приглушённой.
///
/// Так выглядят метка правила, оценка Metacritic и состояние игры. Три
/// места собирали её по отдельности, и заливка у них разошлась: 0.13 и 0.14
/// при одинаковом на вид результате. Ступень теперь одна.
class TonedChip extends StatelessWidget {
  const TonedChip({
    super.key,
    required this.text,
    required this.color,
    required this.style,
    this.padding = const EdgeInsets.symmetric(
      horizontal: EvaporateSpacing.gap,
      vertical: EvaporateSpacing.hair,
    ),
    this.radius = EvaporateTheme.radiusChip,
  });

  final String text;

  /// Цвет смысла: им пишут надпись, им же тонируют подложку.
  final Color color;

  final TextStyle style;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: EvaporateAlpha.subtle),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(text, style: style.copyWith(color: color)),
    );
  }
}
