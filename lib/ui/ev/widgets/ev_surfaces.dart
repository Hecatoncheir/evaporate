import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../glass/ev_glass.dart';
import 'ev_icon.dart';

/// Панель: матовое стекло на ступень выше земли. Сквозь него видно, что
/// делает фон, но ровно настолько, чтобы текст оставался текстом.
class EvPanel extends StatelessWidget {
  const EvPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.glowCorner = false,
    this.grouped = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Тёплое пятно в правом верхнем углу. Не больше одного на экран.
  final bool glowCorner;

  /// Панели одного слоя читают фон один раз на всех.
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    return EvGlass(
      borderRadius: ev.radii.b4,
      grouped: grouped,
      child: Stack(
        children: [
          if (glowCorner)
            Positioned(
              right: -90,
              top: -120,
              width: 260,
              height: 260,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ev.colors.hot1.withValues(alpha: 0.16),
                      ev.colors.hot1.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.66],
                  ),
                ),
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// Два прибора в ряд: слева тот, что говорит, что происходит сейчас,
/// справа — из чего это складывается. На окне уже 900 они встают друг
/// под друга: правый прибор в колонку не читается.
class EvHeadPanels extends StatelessWidget {
  const EvHeadPanels({super.key, required this.left, required this.right});

  final Widget left;
  final Widget right;

  static const breakpoint = 900.0;

  /// Ширина левой панели при ширине ряда [width] — для того, что внутри
  /// неё должно знать свою ширину без `LayoutBuilder`.
  static double leftWidth(Size window, double width) =>
      window.width < breakpoint ? width : (width - EvSpace.l) * 125 / 225;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < breakpoint) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          left,
          const SizedBox(height: EvSpace.l),
          right,
        ],
      );
    }
    // Панели одной высоты, как колонки сетки в прототипе: правая
    // дотягивается до левой, а не висит короче неё.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 125, child: left),
          const SizedBox(width: EvSpace.l),
          Expanded(flex: 100, child: right),
        ],
      ),
    );
  }
}

/// Главное число панели: крупно, лёгким начертанием, с единицей рядом
/// в моноширинном. Единица мельче в три раза — она не число.
class EvBigNumber extends StatelessWidget {
  const EvBigNumber(this.value, {super.key, required this.unit, this.size});

  final String value;
  final String unit;

  /// Кегль; `null` — от ширины окна, как в панелях.
  final double? size;

  /// `clamp(30px, 4.4vw, 50px)` из прототипа.
  static double sizeFor(Size window) => (window.width * .044).clamp(30, 50);

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final size = this.size ?? sizeFor(MediaQuery.sizeOf(context));
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: value),
          TextSpan(
            text: '  $unit',
            style: ev.text.mono(
              ev.text.data,
              size: size * .36,
              color: ev.colors.ink3,
              letterSpacing: size * .018,
            ),
          ),
        ],
      ),
      style: ev.text.big(size),
    );
  }
}

/// Четыре числа сеткой два на два. Тонкие линии между ними — не рамки,
/// а швы: приборы одного прибора.
class EvKpiGrid extends StatelessWidget {
  const EvKpiGrid({super.key, required this.items});

  /// Подпись, значение и цвет значения.
  final List<(String, String, Color)> items;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    Widget cell((String, String, Color) item) => Container(
      color: c.surface,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.$1.toUpperCase(), style: ev.text.label),
          const SizedBox(height: 5),
          Text(
            item.$2,
            maxLines: 1,
            style: ev.text.mono(
              ev.text.data,
              size: 17,
              weight: FontWeight.w500,
              color: item.$3,
            ),
          ),
        ],
      ),
    );
    return ClipRRect(
      borderRadius: ev.radii.b2,
      child: ColoredBox(
        color: c.lineSoft,
        child: Column(
          children: [
            for (var row = 0; row * 2 < items.length; row++) ...[
              if (row > 0) const SizedBox(height: 1),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cell(items[row * 2])),
                    const SizedBox(width: 1),
                    Expanded(child: cell(items[row * 2 + 1])),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Чип: короткая метка на 24 px. Лежит поверх картинки, поэтому сделан
/// из линзы — кадр под ним виден и гнётся у кромки. Горячий вариант —
/// единственный цветной, им помечают текущее состояние объекта.
class EvChip extends StatelessWidget {
  const EvChip(this.label, {super.key, this.hot = false, this.grouped = false});

  final String label;
  final bool hot;

  /// Чипы одной строки читают фон один раз на всех.
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return EvGlass(
      style: EvGlassStyle.lens,
      borderRadius: ev.radii.b1,
      grouped: grouped,
      tint: hot ? c.hot1.withValues(alpha: 0.16) : null,
      keyLight: hot ? c.hot2 : null,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      child: Text(
        label,
        style: ev.text.data.copyWith(
          color: hot ? c.hot2 : c.ink2,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// Состояние процесса: точка плюс подпись. Цвет точки кодирует причину,
/// а не громкость.
enum EvStatus {
  /// Всё хорошо.
  ok,

  /// Что-то идёт прямо сейчас.
  busy,

  /// Ждём внешнего.
  warn,

  /// Нужно решение человека.
  bad,

  /// Просто пауза.
  idle,

  /// Новости, которые ждут: свёрнутый дайджест «Пока вас не было».
  news,
}

class EvPill extends StatelessWidget {
  const EvPill(
    this.label, {
    super.key,
    this.status = EvStatus.ok,
    this.onTap,
    this.dot = true,
  });

  final String label;
  final EvStatus status;
  final VoidCallback? onTap;

  /// Точка состояния слева. Без неё плашка — просто подпись: где вы
  /// в игре, а не что с ней.
  final bool dot;

  Color _dot(EvColors c) => switch (status) {
    EvStatus.ok => EvColors.ok,
    EvStatus.busy => c.cool,
    EvStatus.warn => EvColors.warn,
    EvStatus.bad => EvColors.bad,
    EvStatus.idle => c.ink4,
    EvStatus.news => c.hot2,
  };

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final dot = _dot(ev.colors);
    final tinted =
        status == EvStatus.warn ||
        status == EvStatus.bad ||
        status == EvStatus.news;
    // Таблетки живут в полосе каркаса — под ними уже стекло, второй раз
    // читать фон незачем.
    final pill = EvGlass(
      style: EvGlassStyle.chip,
      backdrop: false,
      borderRadius: ev.radii.bPill,
      tint: tinted ? dot.withValues(alpha: 0.1) : null,
      keyLight: tinted ? dot : null,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      child: SizedBox(
        height: 30,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (this.dot) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dot,
                  boxShadow: [BoxShadow(color: dot, blurRadius: 9)],
                ),
              ),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: ev.text.data.copyWith(
                color: tinted ? dot : ev.colors.ink2,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return pill;
    return GestureDetector(onTap: onTap, child: pill);
  }
}

/// Чем закрашена полоса. Цвет кодирует причину, а не громкость.
enum EvBarTone {
  /// Приём идёт.
  hot,

  /// Данные: проверка, выгрузка.
  cool,

  /// Приём встал, но не сломался.
  stall,

  /// Приём остановлен ошибкой.
  dead,

  /// Перепроверка частей.
  arc,
}

/// Полоса прогресса. Янтарная — приём, циановая — данные и проверка.
/// Погасшие варианты не светятся: полоса, которая никуда не движется,
/// не должна тянуть на себя взгляд.
class EvBar extends StatelessWidget {
  const EvBar(
    this.value, {
    super.key,
    this.cool = false,
    this.tone,
    this.height = 5,
    this.muted = false,
  });

  /// 0…1
  final double value;

  /// Циановый вариант — для данных. То же, что `tone: EvBarTone.cool`,
  /// и оставлено ради коротких вызовов.
  final bool cool;

  /// Заливка. Не задана — [cool] решает между янтарной и циановой.
  final EvBarTone? tone;

  final double height;

  /// Погашенная полоса: завершённое или ждущее, без свечения.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final look = tone ?? (cool ? EvBarTone.cool : EvBarTone.hot);
    final fill = muted
        ? [c.ink4.withValues(alpha: 0.5), c.ink4]
        : switch (look) {
            EvBarTone.hot => [c.hotDeep, c.hot1, c.hot2],
            EvBarTone.cool => [const Color(0xFF1B6F8A), c.cool],
            EvBarTone.stall => [const Color(0xFF4A3410), EvColors.warn],
            EvBarTone.dead => [const Color(0xFF4A1218), EvColors.bad],
            EvBarTone.arc => [const Color(0xFF3A1E63), c.arc],
          };
    // Вставшая полоса не светится и держится приглушённее: она сообщает
    // положение, а не движение.
    final glow = switch (look) {
      EvBarTone.hot => c.hot1,
      EvBarTone.cool => c.cool,
      EvBarTone.arc => c.arc,
      EvBarTone.stall || EvBarTone.dead => null,
    };
    final fade = switch (look) {
      EvBarTone.stall => .7,
      EvBarTone.dead => .75,
      _ => 1.0,
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: [
          // Во всю доступную ширину: под свободными ограничениями полоса
          // иначе схлопнулась бы в ничто.
          SizedBox(
            width: double.infinity,
            height: height,
            child: ColoredBox(color: c.ink.withValues(alpha: 0.055)),
          ),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Opacity(
              opacity: fade,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: fill),
                  boxShadow: muted || glow == null
                      ? null
                      : [
                          BoxShadow(
                            color: glow.withValues(alpha: 0.5),
                            blurRadius: 14,
                          ),
                        ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Пустой раздел: знак, что здесь ничего нет, и чем это заполнить.
/// Не «ошибка» и не «скоро будет» — место, у которого есть вход.
class EvNothing extends StatelessWidget {
  const EvNothing({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    this.action,
  });

  final String icon;
  final String title;
  final String detail;

  /// Что можно сделать прямо отсюда.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final detailStyle = ev.text.data.copyWith(fontSize: 11, height: 1.5);
    return CustomPaint(
      painter: EvDashedBorder(color: c.lineSoft, radius: ev.radii.r4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 42),
        child: Column(
          children: [
            EvIcon(icon, size: 24, color: c.ink4),
            const SizedBox(height: 11),
            Text(
              title,
              textAlign: TextAlign.center,
              style: ev.text.body.copyWith(fontSize: 14, color: c.ink2),
            ),
            const SizedBox(height: 11),
            ConstrainedBox(
              // 44ch моноширинным — та же мера, что в прототипе.
              constraints: BoxConstraints(
                maxWidth: evCharWidth(detailStyle) * 44,
              ),
              child: Text(
                detail,
                textAlign: TextAlign.center,
                style: detailStyle,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 15), action!],
          ],
        ),
      ),
    );
  }
}

/// Пунктирная рамка. Ею обведено то, что ещё не занимает места:
/// раздача в очереди, пустой раздел. Сплошная рамка обещала бы, что
/// внутри уже что-то лежит.
class EvDashedBorder extends CustomPainter {
  EvDashedBorder({
    required this.color,
    required this.radius,
    this.dash = 4,
    this.gap = 4,
  });

  final Color color;
  final double radius;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(.5, .5, size.width - 1, size.height - 1),
          Radius.circular(radius),
        ),
      );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    for (final metric in outline.computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += dash + gap) {
        canvas.drawPath(
          metric.extractPath(at, math.min(at + dash, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(EvDashedBorder old) =>
      old.color != color || old.radius != radius;
}

/// Надглавие: короткая горячая черта и капс моноширинным. Стоит над
/// заголовком героя и над названием в карточке игры.
class EvEyebrow extends StatelessWidget {
  const EvEyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [ev.colors.hot1, ev.colors.hot1.withValues(alpha: 0)],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            text.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ev.text.data.copyWith(
              fontSize: 10.5,
              height: 1.5,
              letterSpacing: 2.31,
              color: ev.colors.hot2,
            ),
          ),
        ),
      ],
    );
  }
}

/// Ширина знака «0» — единица `ch` в CSS: ею меряются колонки текста.
double evCharWidth(TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: '0', style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// Заголовок раздела: капс, счётчик и линия в никуда.
class EvSectionHeader extends StatelessWidget {
  const EvSectionHeader(this.title, {super.key, this.count, this.trailing});

  final String title;
  final String? count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(title.toUpperCase(), style: ev.text.section),
        if (count != null) ...[
          const SizedBox(width: 14),
          Text(count!, style: ev.text.data.copyWith(color: ev.colors.ink4)),
        ],
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [ev.colors.line, ev.colors.line.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 14), trailing!],
      ],
    );
  }
}
