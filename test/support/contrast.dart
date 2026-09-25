import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Относительная яркость по WCAG.
double luminance(Color color) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// Отношение контраста двух цветов: от 1 (неразличимы) до 21.
double contrast(Color a, Color b) {
  final la = luminance(a);
  final lb = luminance(b);
  final light = math.max(la, lb);
  final dark = math.min(la, lb);
  return (light + 0.05) / (dark + 0.05);
}
