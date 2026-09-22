import 'package:flutter/material.dart';

import '../theme.dart';
import 'glass_surface.dart';
import 'section_card_header.dart';

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
      padding: const EdgeInsets.only(bottom: EvaporateSpacing.panel),
      child: GlassSurface(
        radius: EvaporateTheme.radiusPanel,
        opacity: HardwareSurfaceTheme.of(context).cardOpacity,
        padding: const EdgeInsets.all(EvaporateSpacing.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionCardHeader(title: title, icon: icon, trailing: trailing),
            child,
          ],
        ),
      ),
    );
  }
}
