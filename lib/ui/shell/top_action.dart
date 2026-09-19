import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/hover_builder.dart';

/// Клавиша верхней рейки. Под курсором подсвечивается и чуть поднимается —
/// на строке из одинаковых квадратов это единственный способ показать, где
/// именно сейчас рука.
class TopAction extends StatelessWidget {
  const TopAction({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.hiddenLabel,
    this.danger = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final String? hiddenLabel;

  /// Действие, которое закрывает приложение. Подсвечивается тревожным
  /// цветом только под курсором: постоянно красная кнопка выхода в углу
  /// читалась бы как поломка.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = danger ? colors.danger : colors.primary;
    return HoverBuilder(
      builder: (context, hovered, _) => AnimatedContainer(
        duration: context.motion.fast,
        curve: EvaporateMotion.ease,
        transform: Matrix4.translationValues(0, hovered ? -1 : 0, 0),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 18),
              if (hiddenLabel case final label?)
                SizedBox.shrink(child: ExcludeSemantics(child: Text(label))),
            ],
          ),
          style: IconButton.styleFrom(
            minimumSize: const Size(38, 38),
            backgroundColor: hovered
                ? colors.surfaceHigh
                : colors.surface.withValues(alpha: EvaporateAlpha.strong),
            foregroundColor: hovered ? accent : colors.textSecondary,
            side: BorderSide(
              color: hovered
                  ? accent.withValues(alpha: EvaporateAlpha.strong)
                  : colors.outline,
            ),
          ),
        ),
      ),
    );
  }
}
