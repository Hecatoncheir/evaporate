import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/decorative_motion.dart';

/// Полоса света, раз в несколько секунд проходящая по крупной обложке.
///
/// Это единственное, что двигается по картинке само, и именно она отличает
/// живой кадр от вклеенной картинки. Между проходами — длинная пауза:
/// блик, бегущий без остановки, через минуту начинает раздражать, а
/// редкий замечают краем глаза и не устают от него.
class HeroSweep extends StatelessWidget {
  const HeroSweep({super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      child,
      if (enabled)
        // Часы гонят кадры, ни разу не пересобирая обложку под полосой.
        DecorativeMotion(
          enabled: true,
          builder: (context, clock, _) => IgnorePointer(
            child: CustomPaint(
              painter: _SweepPainter(clock: clock, color: AppColors.artSweep),
            ),
          ),
        ),
    ],
  );
}

class _SweepPainter extends CustomPainter {
  _SweepPainter({required this.clock, required this.color})
    : super(repaint: clock);

  final ValueListenable<double> clock;
  final Color color;

  /// Сколько длится цикл и сколько из него занимает сам проход.
  static const _period = 7.5;
  static const _cross = 2.4;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final phase = clock.value % _period;
    if (phase > _cross) return;

    final travel = Curves.easeInOutSine.transform(phase / _cross);
    final band = size.width * 0.3;
    final center = -band + travel * (size.width + band * 2);
    final rect = Rect.fromLTRB(
      center - band,
      -size.height,
      center + band,
      size.height * 2,
    );

    // Гаснет к началу и к концу прохода: иначе полоса возникала бы у края
    // сразу в полную силу и так же обрывалась.
    final fade = (1 - (travel * 2 - 1).abs()).clamp(0.0, 1.0);
    final paint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = LinearGradient(
        colors: [
          AppColors.transparent,
          color.withValues(alpha: color.a * fade),
          AppColors.transparent,
        ],
      ).createShader(rect);

    canvas.save();
    // Наклон: вертикальная полоса читалась бы как шов между слоями.
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.26);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SweepPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.clock != clock;
}
