import 'package:flutter/material.dart';

import '../theme.dart';
import 'glass_surface.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassSurface(
        radius: EvaporateTheme.radiusPanel,
        opacity: HardwareSurfaceTheme.of(context).cardOpacity,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: context.colors.textSecondary),
                  const SizedBox(width: 8),
                ],

                Expanded(child: Text(title, style: context.text.subtitle)),
                ?trailing,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
