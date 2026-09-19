import 'package:flutter/material.dart';

import '../theme.dart';
import 'app_footer.dart';

/// Подвал идёт во всю ширину окна и потому вылезает за поля панели.
class ShellFooterStrip extends StatelessWidget {
  const ShellFooterStrip({super.key, required this.width});

  /// Ширина окна, а не панели: подвал шире своих полей.
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: EvaporateLayout.footerHeight,
      child: OverflowBox(
        maxWidth: width,
        child: SizedBox(width: width, child: const AppFooter()),
      ),
    );
  }
}
