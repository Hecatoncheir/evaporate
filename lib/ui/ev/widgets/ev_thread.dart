import 'package:flutter/widgets.dart';

import '../design/theme.dart';

/// Нить событий: вертикальная линия с точками.
///
/// Одна и та же в ленте сохранений и в ленте друзей — событие в системе
/// выглядит одинаково, где бы оно ни было. Линия растворяется на концах,
/// чтобы у ленты не было «дна»: она не кончилась, просто дальше уже
/// не сегодня.
class EvThread extends StatelessWidget {
  const EvThread({super.key, required this.children});

  final List<Widget> children;

  /// Отступ содержимого слева под нить.
  static const rail = 26.0;

  /// Где проходит сама нить.
  static const line = 7.0;

  @override
  Widget build(BuildContext context) {
    final c = context.ev.colors;
    return CustomPaint(
      painter: _ThreadPainter(line: c.line),
      child: Padding(
        padding: const EdgeInsets.only(left: rail, top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _ThreadPainter extends CustomPainter {
  _ThreadPainter({required this.line});

  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(EvThread.line, 6, 1, size.height - 12);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            line.withValues(alpha: 0),
            line,
            line,
            line.withValues(alpha: 0),
          ],
          stops: const [0, .12, .88, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_ThreadPainter old) => old.line != line;
}

/// Событие на нити: точка слева и содержимое справа. Верхняя точка
/// горит, остальные — только контур: лента читается сверху вниз,
/// от «прямо сейчас» к «когда-то».
class EvThreadRow extends StatelessWidget {
  const EvThreadRow({
    super.key,
    required this.child,
    this.now = false,
    this.dotTop = 19,
  });

  final Widget child;
  final bool now;

  /// На какой высоте строки сидит точка.
  final double dotTop;

  @override
  Widget build(BuildContext context) {
    final c = context.ev.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -EvThread.rail + EvThread.line - 3.5,
          top: dotTop,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: now ? c.hot2 : c.ground,
              border: Border.all(color: now ? c.hot2 : c.ink4, width: 1.5),
              boxShadow: now
                  ? [BoxShadow(color: c.hot2, blurRadius: 14)]
                  : null,
            ),
          ),
        ),
        child,
      ],
    );
  }
}
