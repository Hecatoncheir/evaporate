import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../theme.dart';

/// Атлас один на приложение: неизменные штрихи и их ореолы растрируются
/// один раз, а не размываются тысячами заново каждый кадр. Плотность,
/// траектории и яркости симуляции при этом остаются прежними.
class PortalAtlas {
  static const buckets = 6;
  static const resolution = 3.0;
  static const lengthStep = 0.25;
  static const variants = 25;
  static const padding = 7.0;
  static const cellWidth = 20.0;
  static const cellHeight = 14.0;
  static const pixelWidth = cellWidth * resolution;
  static const pixelHeight = cellHeight * resolution;
  static final ui.Image image = _create();

  static ui.Image _create() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(resolution);
    for (var bucket = 0; bucket < buckets; bucket++) {
      final heat = (bucket + 1) / buckets;
      final glow = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.4 + heat
        ..color = AppColors.portalRim.withValues(alpha: heat * 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      final core = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 0.45 + heat * 0.75
        ..color = Color.lerp(
          AppColors.portalRim,
          AppColors.portalSpark,
          heat * heat,
        )!.withValues(alpha: 0.15 + heat * 0.85);
      for (var variant = 0; variant < variants; variant++) {
        final x = variant * cellWidth + padding;
        final y = bucket * cellHeight + padding;
        final length = variant * lengthStep;
        canvas.drawLine(Offset(x, y), Offset(x + length, y), glow);
        canvas.drawLine(
          Offset(x, y + buckets * cellHeight),
          Offset(x + length, y + buckets * cellHeight),
          core,
        );
      }
    }
    final picture = recorder.endRecording();
    try {
      return picture.toImageSync(
        (variants * pixelWidth).round(),
        (buckets * 2 * pixelHeight).round(),
      );
    } finally {
      picture.dispose();
    }
  }
}
