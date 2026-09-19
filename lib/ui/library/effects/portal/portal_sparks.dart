import 'package:flutter/material.dart';

import '../../../theme.dart';
import '../../../widgets/decorative_motion.dart';
import 'portal_painter.dart';
import 'portal_renderer.dart';
import 'portal_spark_field.dart';

/// Обёртка, рисующая разлёт искр вокруг плитки.
class PortalSparks extends StatefulWidget {
  const PortalSparks({super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<PortalSparks> createState() => PortalSparksState();
}

class PortalSparksState extends State<PortalSparks> {
  /// Разлёт живёт в состоянии, а не в рисовальщике: тот создаётся заново при
  /// каждой пересборке плитки — а плитка пересобирается на каждом переводе
  /// выделения. Искры начинали бы с чистого места и вспыхивали разом.
  @visibleForTesting
  final PortalSparkField field = PortalSparkField();
  late final _renderer = PortalRenderer();

  @override
  void didUpdateWidget(PortalSparks oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      // DecorativeMotion создаёт новые часы при возвращении выделения.
      // Старое показание иначе замораживает первый кадр прежнего потока.
      field.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || MediaQuery.disableAnimationsOf(context)) {
      field.reset();
      return widget.child;
    }

    const halo = PortalSparkField.halo;
    return DecorativeMotion(
      enabled: true,
      child: widget.child,
      // Кайма выходит за плитку, поэтому обрезать нельзя: в ней-то искры и
      // видны. Промежутка между обложками в сетке на неё хватает.
      builder: (context, clock, child) => Stack(
        // Растягиваем: у свободных ограничений обложка без собственного
        // размера схлопнулась бы в точку, и от плитки осталась бы кайма.
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          // Под обложкой: то, что залетело на неё, скрыто, и остаётся ровно
          // разлёт вокруг — а не рябь поверх картинки.
          Positioned(
            left: -halo,
            top: -halo,
            right: -halo,
            bottom: -halo,
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  key: const ValueKey('portal-sparks'),
                  painter: PortalPainter(
                    clock: clock,
                    field: field,
                    renderer: _renderer,
                    blend: EffectsPalette.of(context).sparkBlend,
                  ),
                ),
              ),
            ),
          ),
          child!,
        ],
      ),
    );
  }
}
