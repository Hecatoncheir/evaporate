import 'package:flutter/painting.dart';

/// Искра покидает контур по касательной и дальше летит свободно.
/// Привязка живой частицы к периметру заставляла её огибать углы карточки
/// по рельсам и растягивала след в длинные прямоугольные полосы.
class PortalSpark {
  PortalSpark({
    required this.position,
    required this.velocity,
    required this.twinkle,
    required this.life,
    required this.maxLife,
    required this.trail,
  });

  Offset position;
  Offset velocity;
  final double twinkle;
  double life;
  final double maxLife;
  final double trail;
}
