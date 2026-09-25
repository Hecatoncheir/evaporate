import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../util/plural.dart';
import 'profile_data.dart';

/// Цвет дня на карте: тот же янтарь, что у активности роя, только
/// ступенями — чем больше часов, тем плотнее.
Color evYearColor(EvColors c, int level) => switch (level) {
  0 => c.ink.withValues(alpha: .05),
  1 => c.hot1.withValues(alpha: .28),
  2 => c.hot1.withValues(alpha: .5),
  3 => c.hot1.withValues(alpha: .75),
  _ => c.hot2,
};

/// Год игры: 52 колонки недель по 7 дней. Ячейки квадратные и тянутся
/// во всю ширину панели, но не крупнее [maxCell] — на широком окне
/// карта не должна становиться плакатом.
///
/// В прототипе колонки сетки растягивались, а ячейки в 11 px оставались
/// у левого края своей колонки: промежутки по горизонтали выходили
/// вчетверо шире, чем по вертикали. Здесь шов один на обе оси.
class EvPlayYearMap extends StatelessWidget {
  const EvPlayYearMap({super.key, required this.year});

  final EvPlayYear year;

  static const gap = 3.0;
  static const maxCell = 22.0;

  static double cellFor(double width) => math.min(
    maxCell,
    (width - (EvPlayYear.weeks - 1) * gap) / EvPlayYear.weeks,
  );

  static double heightFor(double width) => cellFor(width) * 7 + gap * 6;

  @override
  Widget build(BuildContext context) {
    final c = context.ev.colors;
    return Semantics(
      label:
          'Год игры: ${ruCount(year.days, 'день', 'дня', 'дней')}, '
          '${ruCount(year.hours, 'час', 'часа', 'часов')}',
      child: LayoutBuilder(
        builder: (context, box) => SizedBox(
          width: box.maxWidth,
          height: heightFor(box.maxWidth),
          child: CustomPaint(
            painter: _YearPainter(
              year: year,
              colors: [for (var l = 0; l <= 4; l++) evYearColor(c, l)],
              glow: c.hot1.withValues(alpha: .65),
            ),
          ),
        ),
      ),
    );
  }
}

class _YearPainter extends CustomPainter {
  _YearPainter({required this.year, required this.colors, required this.glow});

  final EvPlayYear year;
  final List<Color> colors;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = EvPlayYearMap.cellFor(size.width);
    final step = cell + EvPlayYearMap.gap;
    final radius = Radius.circular(cell * .23);
    final fill = Paint();
    // Самые светлые дни чуть светятся — `box-shadow` у `.l4`.
    final halo = Paint()
      ..color = glow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    for (var w = 0; w < EvPlayYear.weeks; w++) {
      for (var d = 0; d < 7; d++) {
        final level = year.level(w, d);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * step, d * step, cell, cell),
          radius,
        );
        if (level == EvPlayYear.maxLevel) canvas.drawRRect(rect, halo);
        canvas.drawRRect(rect, fill..color = colors[level]);
      }
    }
  }

  @override
  bool shouldRepaint(_YearPainter old) =>
      old.year != year || old.colors.first != colors.first;
}

/// Подпись под картой: шкала «меньше — больше» и самая длинная серия.
class EvPlayYearLegend extends StatelessWidget {
  const EvPlayYearLegend({super.key, required this.year});

  final EvPlayYear year;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final style = ev.text.data.copyWith(fontSize: 10, color: c.ink4);
    Widget swatch(int level) => Padding(
      padding: const EdgeInsets.only(right: 7),
      child: Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: evYearColor(c, level),
          borderRadius: BorderRadius.circular(2.5),
        ),
      ),
    );
    return Row(
      children: [
        Text('меньше', style: style),
        const SizedBox(width: 7),
        for (var l = 0; l <= EvPlayYear.maxLevel; l++) swatch(l),
        Text('больше', style: style),
        const SizedBox(width: EvSpace.l),
        Expanded(
          child: Text(
            'Самая длинная серия — '
            '${ruCount(year.longestStreak, 'день', 'дня', 'дней')} подряд',
            textAlign: TextAlign.end,
            style: style,
          ),
        ),
      ],
    );
  }
}
