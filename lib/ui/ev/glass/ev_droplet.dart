import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import 'ev_glass.dart';

/// Капля стекла: подсветка выбранного, которая не гаснет и не зажигается
/// на новом месте, а **перетекает** к нему.
///
/// В полёте капля вытягивается: передний край уходит раньше заднего, а
/// поперёк она на столько же сужается — жидкость не прибавляет в объёме.
/// Это то самое «жидкое» в жидком стекле; в iOS так ходит выделение
/// в панели разделов.
///
/// Кладётся прямо в [Stack]: виджет возвращает [Positioned].
class EvDroplet extends StatefulWidget {
  const EvDroplet({
    super.key,
    required this.rect,
    this.radius,
    this.tint,
    this.duration = EvMotion.hover,
    this.child,
  });

  /// Куда капля должна встать — в координатах [Stack].
  final Rect rect;

  final BorderRadius? radius;

  /// Заливка капли; по умолчанию — светлая плёнка поверх того, на чём
  /// она лежит.
  final Color? tint;

  final Duration duration;

  /// Содержимое внутри капли — обычно его нет: капля лежит под строкой.
  final Widget? child;

  @override
  State<EvDroplet> createState() => _EvDropletState();
}

class _EvDropletState extends State<EvDroplet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );

  late Rect _from = widget.rect;
  late Rect _to = widget.rect;

  @override
  void didUpdateWidget(EvDroplet old) {
    super.didUpdateWidget(old);
    if (widget.rect == _to) return;
    _from = evDropletRect(_from, _to, _flow.value);
    _to = widget.rect;
    if (MediaQuery.disableAnimationsOf(context)) {
      _flow.value = 1;
    } else {
      _flow.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    return AnimatedBuilder(
      animation: _flow,
      builder: (context, child) {
        final rect = evDropletRect(_from, _to, _flow.value);
        return Positioned.fromRect(
          rect: rect,
          child: IgnorePointer(
            child: EvGlass(
              style: EvGlassStyle.droplet,
              backdrop: false,
              tint: widget.tint ?? ev.colors.ink.withValues(alpha: 0.07),
              borderRadius:
                  widget.radius ??
                  BorderRadius.circular(
                    math.min(ev.radii.r2, rect.shortestSide / 2),
                  ),
              child: child ?? const SizedBox.expand(),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Прямоугольник капли на пути из [a] в [b] в момент [t].
///
/// Передний край идёт по своей кривой, задний — по сдвинутой, отсюда
/// растяжение; поперечная сторона ужимается на ту же долю, на какую
/// капля вытянулась.
Rect evDropletRect(Rect a, Rect b, double t) {
  if (t >= 1) return b;
  if (t <= 0) return a;
  const lead = Interval(0, 0.72, curve: EvMotion.easeOut);
  const trail = Interval(0.28, 1, curve: EvMotion.easeOut);
  final l = lead.transform(t);
  final s = trail.transform(t);
  final down = b.center.dy >= a.center.dy;
  final right = b.center.dx >= a.center.dx;
  double edge(double from, double to, bool leading) =>
      from + (to - from) * (leading ? l : s);

  final rect = Rect.fromLTRB(
    edge(a.left, b.left, !right),
    edge(a.top, b.top, !down),
    edge(a.right, b.right, right),
    edge(a.bottom, b.bottom, down),
  );

  final naturalW = a.width + (b.width - a.width) * t;
  final naturalH = a.height + (b.height - a.height) * t;
  final stretchX = naturalW <= 0 ? 0.0 : (rect.width / naturalW - 1);
  final stretchY = naturalH <= 0 ? 0.0 : (rect.height / naturalH - 1);
  final squeezeX = math.min(0.2, math.max(0.0, stretchY) * 0.35) * rect.width;
  final squeezeY = math.min(0.2, math.max(0.0, stretchX) * 0.35) * rect.height;
  return Rect.fromLTRB(
    rect.left + squeezeX / 2,
    rect.top + squeezeY / 2,
    rect.right - squeezeX / 2,
    rect.bottom - squeezeY / 2,
  );
}
