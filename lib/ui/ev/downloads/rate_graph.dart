import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../art/key_art.dart';
import '../design/theme.dart';
import '../design/tokens.dart';

/// Шестьдесят секунд приёма: по одному отсчёту в секунду.
///
/// Последний отсчёт — то число, которое приходит из библиотеки, поэтому
/// график начинается ровно с того значения, которое над ним написано;
/// в прототипе история заполнялась случайными числами, и надпись сразу
/// расходилась с плашкой в верхней полосе.
class EvRateSeries {
  EvRateSeries(double rate, {int seed = 1622}) : _rng = EvArtRandom(seed) {
    for (var i = 0; i < length; i++) {
      _history.add(
        (rate + math.sin(i / 5) * .5 + (_rng.next() - .5) * .9).clamp(
          _low,
          _high,
        ),
      );
    }
    _history[length - 1] = rate;
  }

  static const length = 60;
  static const _low = .25;
  static const _high = 4.2;

  final EvArtRandom _rng;
  final _history = <double>[];

  List<double> get history => List.unmodifiable(_history);

  /// Текущий приём, МБ/с.
  double get rate => _history.last;

  /// Прошла секунда: шаг случайного блуждания, как в прототипе.
  void advance() {
    _history
      ..add((_history.last + (_rng.next() - .48) * .7).clamp(_low, _high))
      ..removeAt(0);
  }
}

/// График приёма. Растягивается по ширине панели, высота — 74 px.
///
/// [EvRateGraph.frames] — тот же график для кадров в оверлее: зелёный,
/// на постоянной шкале, без точки на конце.
class EvRateGraph extends StatelessWidget {
  const EvRateGraph(this.series, {super.key}) : frames = false, height = 74;

  const EvRateGraph.frames(this.series, {super.key, required this.height})
    : frames = true;

  final List<double> series;
  final bool frames;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.ev.colors;
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: frames
            ? _RatePainter(
                series: series,
                line: EvColors.ok,
                fill: EvColors.ok,
                fillAlpha: .34,
                grid: c.lineSoft,
                gridAt: const [1 / 3, 2 / 3],
                scale: (EvFrameScale.low, EvFrameScale.high),
              )
            : _RatePainter(
                series: series,
                line: c.hot2,
                fill: c.hot1,
                grid: c.lineSoft,
                tip: c.ink,
              ),
        size: Size.infinite,
      ),
    );
  }
}

/// Шкала графика кадров: всё, что ниже 96 и выше 168, прижимается к краю.
abstract final class EvFrameScale {
  static const low = 96.0;
  static const high = 168.0;
}

class _RatePainter extends CustomPainter {
  _RatePainter({
    required this.series,
    required this.line,
    required this.fill,
    required this.grid,
    this.tip,
    this.fillAlpha = .42,
    this.gridAt = const [.25, .5, .75],
    this.scale,
  });

  final List<double> series;
  final Color line, fill, grid;
  final double fillAlpha;
  final List<double> gridAt;

  /// Точка на конце линии; `null` — без неё.
  final Color? tip;

  /// Постоянная шкала; `null` — от нуля до потолка по данным.
  final (double, double)? scale;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Потолок не ниже 2.4 МБ/с, иначе тихий приём распирало бы на всю
    // высоту и график врал бы о масштабе.
    final (low, high) =
        scale ?? (0.0, math.max(2.4, series.reduce(math.max)) * 1.12);
    final grid1 = Paint()..color = grid;
    for (final k in gridAt) {
      canvas.drawLine(Offset(0, h * k), Offset(w, h * k), grid1);
    }

    Offset point(int i) => Offset(
      i / (series.length - 1) * w,
      h - 2 - (series[i].clamp(low, high) - low) / (high - low) * (h - 8),
    );

    final path = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < series.length; i++) {
      final p = point(i);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      Path.from(path)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            fill.withValues(alpha: fillAlpha),
            fill.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round
        ..color = line
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6),
    );
    final dot = tip;
    if (dot == null) return;
    final last = point(series.length - 1);
    canvas.drawCircle(
      last.translate(-1, 0),
      3,
      Paint()
        ..color = dot
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 8),
    );
  }

  @override
  bool shouldRepaint(_RatePainter old) =>
      !listEquals(old.series, series) || old.line != line;
}

/// Активность пиров за минуту: 32 × 2 ячейки. Числа не читаются,
/// читается плотность.
class EvPeerHeat extends StatelessWidget {
  const EvPeerHeat({super.key, required this.tick, this.live = true});

  /// Номер шага. Из него и постоянного зерна получается раскладка:
  /// картинка живая, но воспроизводимая.
  final int tick;

  /// Есть ли с кем обмениваться. Пиров нет — сетка холодная целиком,
  /// а не мигает обменом, которого не происходит.
  final bool live;

  static const columns = 32;
  static const rows = 2;
  static const gap = 2.0;

  /// Высота карты — следствие ширины: ячейки квадратные.
  static double heightFor(double width) =>
      (width - (columns - 1) * gap) / columns * rows + gap * (rows - 1);

  @override
  Widget build(BuildContext context) {
    final c = context.ev.colors;
    return _HeatBox(
      child: CustomPaint(
        painter: _HeatPainter(
          tick: live ? tick : -1,
          cold: c.lineSoft,
          warm: c.ink.withValues(alpha: .14),
          hues: [c.hot1, c.hot2, c.cool, c.arc],
        ),
        size: Size.infinite,
      ),
    );
  }
}

/// Коробка, которая берёт ширину и сама считает высоту. Тем же занимался
/// бы `LayoutBuilder`, но он не умеет отвечать о своих размерах заранее,
/// а панель рядом равняется по высоте именно так.
class _HeatBox extends SingleChildRenderObjectWidget {
  const _HeatBox({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHeatBox();
}

class _RenderHeatBox extends RenderProxyBox {
  @override
  double computeMinIntrinsicHeight(double width) => EvPeerHeat.heightFor(width);

  @override
  double computeMaxIntrinsicHeight(double width) => EvPeerHeat.heightFor(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final width = constraints.biggest.width;
    return Size(width, EvPeerHeat.heightFor(width));
  }

  @override
  void performLayout() {
    size = computeDryLayout(constraints);
    child?.layout(BoxConstraints.tight(size));
  }
}

class _HeatPainter extends CustomPainter {
  _HeatPainter({
    required this.tick,
    required this.cold,
    required this.warm,
    required this.hues,
  });

  final int tick;
  final Color cold, warm;
  final List<Color> hues;

  static const _count = EvPeerHeat.columns * EvPeerHeat.rows;

  @override
  void paint(Canvas canvas, Size size) {
    final live = tick >= 0;
    final cell =
        (size.width - (EvPeerHeat.columns - 1) * EvPeerHeat.gap) /
        EvPeerHeat.columns;
    // Тот же генератор, что в прототипе, и та же последовательность
    // вызовов: раскладка шага воспроизводится по его номеру.
    final rng = EvArtRandom(4242);
    for (var step = 0; step < tick; step++) {
      for (var i = 0; i < _count; i++) {
        if (rng.next() > .80) rng.next();
      }
    }
    final paint = Paint();
    for (var i = 0; i < _count; i++) {
      final v = live ? rng.next() : 0.0;
      final hot = v > .80;
      paint
        ..color = hot
            ? hues[(i + tick) % hues.length].withValues(
                alpha: .35 + rng.next() * .65,
              )
            : v > .55
            ? warm
            : cold
        ..maskFilter = hot ? const MaskFilter.blur(BlurStyle.solid, 3) : null;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            (i % EvPeerHeat.columns) * (cell + EvPeerHeat.gap),
            (i ~/ EvPeerHeat.columns) * (cell + EvPeerHeat.gap),
            cell,
            cell,
          ),
          const Radius.circular(1.5),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HeatPainter old) => old.tick != tick || old.cold != cold;
}

/// Кольцо частей: получено, в работе, на проверке и ещё не запрошено.
/// Доли приходят посчитанными из гигабайтов, поэтому кольцо и подписи
/// под ним не могут разойтись.
class EvSwarmRing extends StatelessWidget {
  const EvSwarmRing({
    super.key,
    required this.received,
    required this.inFlight,
    required this.verifying,
    this.size = 132,
  });

  /// Доли 0…1.
  final double received, inFlight, verifying;

  final double size;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          shares: [received, inFlight, verifying],
          colors: [c.hot1, c.cool, c.arc],
          track: c.ink.withValues(alpha: .06),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(received * 100).round()}',
                style: ev.text.display(24).copyWith(height: 1),
              ),
              const SizedBox(height: 4),
              Text(
                '% ГОТОВО',
                style: ev.text.mono(
                  ev.text.data,
                  size: 9,
                  weight: FontWeight.w500,
                  letterSpacing: 1.26,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.shares,
    required this.colors,
    required this.track,
  });

  /// Доли 0…1 в порядке отрисовки.
  final List<double> shares;
  final List<Color> colors;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    // Геометрия кольца из прототипа: радиус 46 и толщина 13 на сетке 120.
    final k = size.width / 120;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: 46 * k,
    );
    canvas.drawCircle(
      rect.center,
      rect.width / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13 * k
        ..color = track,
    );

    // Первый сегмент начинается на двенадцати часах и идёт по часовой.
    var start = -math.pi / 2;
    for (var i = 0; i < shares.length; i++) {
      final sweep = shares[i] * 2 * math.pi;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 13 * k
          ..strokeCap = StrokeCap.round
          ..color = colors[i]
          ..maskFilter = i == 0
              ? const MaskFilter.blur(BlurStyle.solid, 8)
              : null,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      !listEquals(old.shares, shares) || !listEquals(old.colors, colors);
}
