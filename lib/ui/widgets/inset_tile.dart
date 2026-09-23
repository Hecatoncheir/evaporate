import 'package:flutter/material.dart';

import '../theme.dart';

/// Строка-карточка внутри раздела: приподнятая подложка с кантом.
///
/// Так выглядят правило сохранений, снимок, пакет с другого устройства и
/// список папок наблюдения. Каждый собирал это обрамление сам, и от места
/// к месту оно разъезжалось полями.
///
/// Под курсором ([hovered]) строка берёт фирменный оттенок и кант. Следит
/// за курсором тот, кто строку ставит: от наведения у него меняется не
/// только подложка, но и значки внутри.
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
    this.hovered = false,
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedContainer(
      duration: context.motion.fast,
      curve: EvaporateMotion.ease,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: hovered
            ? Color.lerp(
                colors.surfaceHigh,
                colors.primary,
                EvaporateAlpha.tint,
              )
            : colors.surfaceHigh,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: hovered
              ? colors.primary.withValues(alpha: EvaporateAlpha.strong)
              : colors.outline,
        ),
      ),
      child: child,
    );
  }
}
