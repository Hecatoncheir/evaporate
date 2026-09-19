import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'portal_atlas.dart';
import 'portal_spark_field.dart';
import 'spark_batch.dart';

/// Собирает кадр снопа: обод по кромке и живые искры — в пачки по яркости,
/// каждая одним вызовом атласа.
class PortalRenderer {
  final _batches = List.generate(PortalAtlas.buckets, (_) => SparkBatch());
  final _paint = Paint()..filterQuality = FilterQuality.low;
  Size _size = Size.zero;
  Float64List _rim = Float64List(0);

  void _resize(PortalSparkField field) {
    if (_size == field.size) return;
    _size = field.size;
    final segments = ((_size.width + _size.height) * 2 / 1.4).ceil();
    _rim = Float64List(segments * 10);
    for (var i = 0; i < segments; i++) {
      final at = i / segments;
      final edge = field.outline.edgeAt(at);
      final j = i * 10;
      _rim[j] = edge.point.dx;
      _rim[j + 1] = edge.point.dy;
      _rim[j + 2] = edge.outward.dx;
      _rim[j + 3] = edge.outward.dy;
      _rim[j + 4] = edge.along.dx;
      _rim[j + 5] = edge.along.dy;
      _rim[j + 6] = math.sin(at * math.pi * 10);
      _rim[j + 7] = math.cos(at * math.pi * 10);
      _rim[j + 8] = math.sin(i * 2.399);
      _rim[j + 9] = math.cos(i * 2.399);
    }
  }

  void paint(
    Canvas canvas,
    PortalSparkField field, {
    required BlendMode blend,
  }) {
    _resize(field);
    for (final batch in _batches) {
      batch.length = 0;
    }
    // Геометрия контура постоянна. Формулы сложения синусов оставляют
    // четыре тригонометрических вызова на кадр вместо двух на каждый штрих.
    final waveSin = math.sin(field.time * 4.1);
    final waveCos = math.cos(field.time * 4.1);
    final grainSin = math.sin(field.time * 19);
    final grainCos = math.cos(field.time * 19);
    for (var i = 0; i < _rim.length; i += 10) {
      final wave = _rim[i + 6] * waveCos - _rim[i + 7] * waveSin;
      final grain = _rim[i + 8] * grainCos + _rim[i + 9] * grainSin;
      final intensity = (0.35 + wave * 0.35 + grain * 0.3).clamp(0.0, 1.0);
      if (intensity < 0.22) continue;
      final x = _rim[i] + _rim[i + 2] * (1.4 + grain * 0.8);
      final y = _rim[i + 1] + _rim[i + 3] * (1.4 + grain * 0.8);
      final trail = 0.6 + intensity * 2.4;
      final bucket = (intensity * (PortalAtlas.buckets - 1)).round();
      _batches[bucket].add(
        bucket,
        x - _rim[i + 4] * trail,
        y - _rim[i + 5] * trail,
        x,
        y,
      );
    }
    for (final spark in field.sparks) {
      final brightness = field.brightnessOf(spark);
      if (brightness < 0.035) continue;
      final bucket = math.min(
        PortalAtlas.buckets - 1,
        (brightness * PortalAtlas.buckets).floor(),
      );
      final x = spark.position.dx;
      final y = spark.position.dy;
      _batches[bucket].add(
        bucket,
        x - spark.velocity.dx * spark.trail,
        y - spark.velocity.dy * spark.trail,
        x,
        y,
      );
    }
    _paint.blendMode = blend;
    for (final batch in _batches) {
      batch.paint(canvas, _paint);
    }
  }
}
