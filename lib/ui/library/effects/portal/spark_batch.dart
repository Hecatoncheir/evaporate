import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'portal_atlas.dart';

/// Буферы живут вместе с карточкой и переиспользуются на каждом кадре.
/// Вместо списков double и их копирования остаются только короткие views.
class SparkBatch {
  Float32List _transforms = Float32List(256 * 4);
  Float32List _glowRects = Float32List(256 * 4);
  Float32List _coreRects = Float32List(256 * 4);
  int length = 0;

  void add(int bucket, double x0, double y0, double x1, double y1) {
    if (length + 4 > _transforms.length) {
      final capacity = _transforms.length * 2;
      _transforms = Float32List(capacity)..setAll(0, _transforms);
      _glowRects = Float32List(capacity)..setAll(0, _glowRects);
      _coreRects = Float32List(capacity)..setAll(0, _coreRects);
    }
    final dx = x1 - x0;
    final dy = y1 - y0;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance < 0.0001) return;
    final cosine = dx / distance / PortalAtlas.resolution;
    final sine = dy / distance / PortalAtlas.resolution;
    const inset = PortalAtlas.padding * PortalAtlas.resolution;
    final variant = (distance / PortalAtlas.lengthStep).round().clamp(
      0,
      PortalAtlas.variants - 1,
    );
    final left = variant * PortalAtlas.pixelWidth;
    final top = bucket * PortalAtlas.pixelHeight;
    const coreOffset = PortalAtlas.buckets * PortalAtlas.pixelHeight;
    final i = length;
    _transforms[i] = cosine;
    _transforms[i + 1] = sine;
    _transforms[i + 2] = x0 - cosine * inset + sine * inset;
    _transforms[i + 3] = y0 - sine * inset - cosine * inset;
    _glowRects[i] = _coreRects[i] = left;
    _glowRects[i + 1] = top;
    _coreRects[i + 1] = top + coreOffset;
    _glowRects[i + 2] = _coreRects[i + 2] = left + PortalAtlas.pixelWidth;
    _glowRects[i + 3] = top + PortalAtlas.pixelHeight;
    _coreRects[i + 3] = top + coreOffset + PortalAtlas.pixelHeight;
    length += 4;
  }

  void paint(Canvas canvas, Paint paint) {
    if (length == 0) return;
    final transforms = Float32List.sublistView(_transforms, 0, length);
    // Порядок проходов такой же, как у исходного эффекта: ореолы корзины,
    // затем её сердцевины. Это сохраняет смешение пересекающихся искр.
    canvas.drawRawAtlas(
      PortalAtlas.image,
      transforms,
      Float32List.sublistView(_glowRects, 0, length),
      null,
      null,
      null,
      paint,
    );
    canvas.drawRawAtlas(
      PortalAtlas.image,
      transforms,
      Float32List.sublistView(_coreRects, 0, length),
      null,
      null,
      null,
      paint,
    );
  }
}
