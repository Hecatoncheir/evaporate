import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import 'ritual_timeline.dart';

/// Ядро ритуала, 170 × 170: неподвижная дорожка, два пунктирных кольца,
/// которые медленно вращаются навстречу друг другу, дуга прогресса и
/// светящийся шар. Перенос `.core` прототипа — его SVG и `.orb`.
///
/// Шар — нарисованный источник света, а не элемент интерфейса, поэтому он
/// круглый при любом потолке радиуса.
class EvRitualCore extends StatefulWidget {
  const EvRitualCore({
    super.key,
    required this.elapsed,
    required this.progress,
    this.still = false,
  });

  /// Время ритуала: от него вращаются кольца и дышит шар.
  final ValueListenable<Duration> elapsed;

  /// Дуга прогресса, 0…1.
  final ValueListenable<double> progress;

  /// «Уменьшить движение»: кольца стоят, шар не дышит.
  final bool still;

  static const size = 170.0;

  @override
  State<EvRitualCore> createState() => _EvRitualCoreState();
}

class _EvRitualCoreState extends State<EvRitualCore> {
  ui.Image? _orb;
  (EvColors, double)? _orbKey;

  @override
  void dispose() {
    _orb?.dispose();
    super.dispose();
  }

  /// Шар растром, с запасом на вдох в 1,11: тени в 50 и 130 px
  /// размываются один раз, а не на каждом кадре дыхания.
  ui.Image _orbFor(EvColors colors, double devicePixelRatio) {
    final key = (colors, devicePixelRatio * 1.11);
    if (_orb == null || _orbKey != key) {
      _orb?.dispose();
      _orb = paintEvOrb(colors, key.$2);
      _orbKey = key;
    }
    return _orb!;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.evc;
    return SizedBox.square(
      dimension: EvRitualCore.size,
      child: CustomPaint(
        painter: _CorePainter(
          elapsed: widget.elapsed,
          progress: widget.progress,
          colors: colors,
          orb: _orbFor(colors, MediaQuery.devicePixelRatioOf(context)),
          still: widget.still,
        ),
      ),
    );
  }
}

/// Сторона растра шара в логических пикселях: радиус 32 и три сигмы
/// самой широкой тени, 65, в каждую сторону.
const _orbSide = 460.0;

/// Шар ядра 64 × 64 со свечением, растром в масштабе [scale] пикселей на
/// логический — по центру картинки стороной [_orbSide].
///
/// * `radial-gradient(circle at 36% 32%, #fff, hot-2 34%, hot-1 62%,
///   hot-deep)` — радиус до дальнего угла, 59,8 px;
/// * `box-shadow: 0 0 50px glow/.9, 0 0 130px glow/.55` — размытие CSS
///   в сигмах вдвое меньше: 25 и 65, первая тень лежит сверху;
/// * `inset 0 -8px 20px rgba(120,20,0,.6)` — тёмный серп снизу внутри.
@visibleForTesting
ui.Image paintEvOrb(EvColors colors, double scale) {
  const r = 32.0;
  const center = Offset(_orbSide / 2, _orbSide / 2);
  final orb = Rect.fromCircle(center: center, radius: r);
  final px = (_orbSide * scale).ceil();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(px / _orbSide);
  canvas
    ..drawCircle(
      center,
      r,
      Paint()
        ..color = colors.hot1.withValues(alpha: .55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 65),
    )
    ..drawCircle(
      center,
      r,
      Paint()
        ..color = colors.hot1.withValues(alpha: .9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25),
    );

  final focus = orb.topLeft + Offset(orb.width * .36, orb.height * .32);
  canvas.drawOval(
    orb,
    Paint()
      ..shader = ui.Gradient.radial(
        focus,
        (orb.bottomRight - focus).distance,
        [const Color(0xFFFFFFFF), colors.hot2, colors.hot1, colors.hotDeep],
        const [0, .34, .62, 1],
      ),
  );

  canvas
    ..save()
    ..clipPath(Path()..addOval(orb))
    ..drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(orb.inflate(40))
        ..addOval(orb.shift(const Offset(0, -8))),
      Paint()
        ..color = const Color.fromRGBO(120, 20, 0, .6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    )
    ..restore();

  final picture = recorder.endRecording();
  final image = picture.toImageSync(px, px);
  picture.dispose();
  return image;
}

class _CorePainter extends CustomPainter {
  _CorePainter({
    required this.elapsed,
    required this.progress,
    required this.colors,
    required this.orb,
    required this.still,
  }) : super(repaint: Listenable.merge([elapsed, progress]));

  final ValueListenable<Duration> elapsed;
  final ValueListenable<double> progress;
  final EvColors colors;
  final ui.Image orb;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final t = still ? Duration.zero : elapsed.value;

    // дорожка
    canvas.drawCircle(
      center,
      66,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color.fromRGBO(255, 255, 255, .07),
    );
    // stroke-dasharray="3 7" · 18 с по часовой
    _dashes(
      canvas,
      center,
      radius: 55,
      dash: 3,
      gap: 7,
      turn: _turn(t, EvRitualTiming.innerTurn),
      color: colors.hot1.withValues(alpha: .25),
    );
    // stroke-dasharray="1 12" · 26 с против часовой
    _dashes(
      canvas,
      center,
      radius: 78,
      dash: 1,
      gap: 12,
      turn: -_turn(t, EvRitualTiming.outerTurn),
      color: colors.hot1.withValues(alpha: .16),
    );
    _arc(canvas, center, progress.value);
    _orb(canvas, center, still ? 0 : evOrbBreath(t));
  }

  static double _turn(Duration t, Duration period) =>
      (t.inMicroseconds % period.inMicroseconds) /
      period.inMicroseconds *
      2 *
      math.pi;

  /// Пунктир по окружности, как у SVG: от трёх часов по часовой стрелке,
  /// последний штрих там, где его застал конец окружности.
  static void _dashes(
    Canvas canvas,
    Offset center, {
    required double radius,
    required double dash,
    required double gap,
    required double turn,
    required Color color,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final length = 2 * math.pi * radius;
    final path = Path();
    for (var s = 0.0; s < length; s += dash + gap) {
      path.addArc(rect, turn + s / radius, math.min(dash, length - s) / radius);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color,
    );
  }

  /// Дуга прогресса от двенадцати часов, 2,2 px, скруглённые концы и
  /// `drop-shadow(0 0 10px hot-2)` — сигма 5 под дугой.
  void _arc(Canvas canvas, Offset center, double p) {
    if (p <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: 66);
    final sweep = 2 * math.pi * p.clamp(0.0, 1.0);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = colors.hot2;
    canvas
      ..drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..color = colors.hot2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      )
      ..drawArc(rect, -math.pi / 2, sweep, false, paint);
  }

  /// Шар дышит: масштаб до 1,11 и яркость до +20 % вместе со свечением.
  void _orb(Canvas canvas, Offset center, double breath) {
    final b = 1 + .2 * breath;
    final side = _orbSide * (1 + .11 * breath);
    canvas.drawImageRect(
      orb,
      Rect.fromLTWH(0, 0, orb.width.toDouble(), orb.height.toDouble()),
      Rect.fromCenter(center: center, width: side, height: side),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = ColorFilter.matrix([
          b, 0, 0, 0, 0, //
          0, b, 0, 0, 0, //
          0, 0, b, 0, 0, //
          0, 0, 0, 1, 0, //
        ]),
    );
  }

  @override
  bool shouldRepaint(_CorePainter old) =>
      old.elapsed != elapsed ||
      old.progress != progress ||
      old.colors != colors ||
      old.orb != orb ||
      old.still != still;
}
