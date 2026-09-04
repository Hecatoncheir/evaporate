import 'package:flutter/material.dart';

/// Один и тот же знак в панели окна, библиотеке и системных ресурсах.
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 28});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.22),
    child: Image.asset(
      'assets/branding/app_icon.png',
      width: size,
      height: size,
    ),
  );
}
