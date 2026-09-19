import 'package:flutter/material.dart';

import '../theme.dart';

/// Мелкая клавиша со значком — пауза, отмена, удаление из очереди.
///
/// Голый `IconButton` на плотной подложке карточки терялся: значок в два
/// волоска служебного цвета читается как украшение, а не как орган
/// управления, и найти его глазами на графике загрузки было нечем.
/// Подложка с кантом — тот же приём, что у [StatusChip]: цвет в четырнадцать
/// процентов под содержимым в полную силу.
///
/// Область нажатия остаётся прежней. Это не придирка: [danger] у отмены
/// выбрасывает скачанное, и делать такую клавишу **крупнее** значило бы
/// покупать заметность ценой случайных попаданий.
class IconAction extends StatelessWidget {
  const IconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Действие теряет сделанное — отмена загрузки выбрасывает скачанное.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? context.colors.danger : context.colors.primary;
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withValues(alpha: EvaporateAlpha.subtle),
        side: BorderSide(color: color.withValues(alpha: EvaporateAlpha.rim)),
        minimumSize: const Size(30, 30),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
