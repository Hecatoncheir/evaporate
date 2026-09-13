import 'package:flutter/material.dart';

import '../widgets/common.dart';

/// Обычная кнопка запуска в цветах темы, без декоративных эффектов.
class PlayButton extends StatelessWidget {
  const PlayButton({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => LauncherActionButton(
    onPressed: onPressed,
    icon: Icons.play_arrow_rounded,
    label: label,
  );
}
