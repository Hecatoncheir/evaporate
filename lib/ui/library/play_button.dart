import 'package:flutter/material.dart';

/// Обычная кнопка запуска в цветах темы, без декоративных эффектов.
class PlayButton extends StatelessWidget {
  const PlayButton({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: const Icon(Icons.play_arrow_rounded, size: 20),
    label: Text(label),
  );
}
