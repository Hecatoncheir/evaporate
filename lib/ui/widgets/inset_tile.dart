import 'package:flutter/material.dart';

import '../theme.dart';

/// Строка-карточка внутри раздела: приподнятая подложка с кантом.
///
/// Так выглядят правило сохранений, снимок, пакет с другого устройства и
/// список папок наблюдения. Каждый собирал это обрамление сам, и от места
/// к месту оно разъезжалось полями.
class InsetTile extends StatelessWidget {
  const InsetTile({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.only(bottom: EvaporateSpacing.gap),
    this.padding = const EdgeInsets.symmetric(
      horizontal: EvaporateSpacing.field,
      vertical: EvaporateSpacing.cluster,
    ),
    this.radius = EvaporateTheme.radiusControl,
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surfaceHigh,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: colors.outline),
      ),
      child: child,
    );
  }
}
