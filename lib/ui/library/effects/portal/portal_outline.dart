import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Точка кромки и две оси в ней: наружу и вдоль обхода.
typedef PortalEdge = ({Offset point, Offset outward, Offset along});

/// Кромка, по которой рождаются искры: прямоугольник обложки со
/// скруглёнными углами.
///
/// Скругление тут не украшение: у острого угла наружу некуда лететь по
/// диагонали — нормаль скачком переходит с одной стороны на другую, и угол
/// выглядит срезанным. На дуге она поворачивается плавно, и сноп огибает
/// угол.
///
/// Живёт отдельно от снопа: от размера обложки она зависит, а от времени,
/// случайности и числа частиц — нет, и проверять её так можно одной
/// подстановкой размера.
class PortalOutline {
  PortalOutline({this.size = Size.zero});

  static const corner = 8.0;

  Size size;

  static const _up = Offset(0, -1);
  static const _down = Offset(0, 1);
  static const _right = Offset(1, 0);

  /// Точка кромки по доле пути [at] вдоль периметра.
  PortalEdge edgeAt(double at) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) {
      return (point: Offset.zero, outward: _up, along: _right);
    }

    final r = math.min(corner, math.min(w, h) / 2);
    final half = (w - r * 2) + (h - r * 2) + math.pi * r;

    final t = at % 1.0;
    final s = (t < 0 ? t + 1 : t) * half * 2;

    // Контур симметричен повороту на пол-оборота: низ — это верх, левая
    // сторона — правая. Поэтому сторон выписано четыре, а не восемь, и
    // расходиться половинам негде.
    if (s < half) return _firstHalf(s, r);
    final edge = _firstHalf(s - half, r);
    return (
      point: Offset(w, h) - edge.point,
      outward: -edge.outward,
      along: -edge.along,
    );
  }

  /// Верхняя сторона, правый верхний угол, правая сторона и правый нижний
  /// угол — в порядке обхода по часовой стрелке.
  PortalEdge _firstHalf(double at, double r) {
    final w = size.width;
    final flatX = w - r * 2;
    final flatY = size.height - r * 2;
    final quarter = math.pi / 2 * r;

    var s = at;
    if (s < flatX) {
      return (point: Offset(r + s, 0), outward: _up, along: _right);
    }
    s -= flatX;
    if (s < quarter) return _arc(Offset(w - r, r), r, -math.pi / 2 + s / r);
    s -= quarter;
    if (s < flatY) {
      return (point: Offset(w, r + s), outward: _right, along: _down);
    }
    s -= flatY;
    // Накопленная погрешность у самого конца полуоборота: дуга всё равно
    // своя, и доводить её до конца вернее, чем возвращаться в начало.
    return _arc(Offset(w - r, size.height - r), r, math.max(s, 0) / r);
  }

  /// Точка на дуге угла: наружу — от центра дуги, вдоль — по касательной.
  static PortalEdge _arc(Offset center, double radius, double angle) {
    final outward = Offset(math.cos(angle), math.sin(angle));
    return (
      point: center + outward * radius,
      outward: outward,
      along: Offset(-outward.dy, outward.dx),
    );
  }
}
