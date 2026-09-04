import 'package:flutter/material.dart';

/// The standard themed Play action, without decorative effects.
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
