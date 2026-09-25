import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Неподвижный фон — на случай, когда шейдер недоступен.
///
/// Два слоя без движения:
/// * тёплое эллиптическое пятно справа сверху — ровно тот запасной фон,
///   который прототип рисует, когда WebGL недоступен;
/// * жерло у нижней кромки — усреднённое ядро плюма из шейдера
///   (`core` в точке 0.16, −0.62), чтобы тепло шло оттуда же, откуда пар.
void paintStaticBackdrop(
  Canvas canvas,
  Size size, {
  required Color hot,
  required Color vent,
}) {
  final rect = Offset.zero & size;
  final w = size.width, h = size.height;

  // radial-gradient(70% 90% at 72% 12%, hot / .13, transparent 60%)
  canvas.drawRect(
    rect,
    Paint()
      ..shader = _ellipse(
        Offset(w * 0.72, h * 0.12),
        w * 0.7,
        h * 0.9,
        [hot.withValues(alpha: 0.13), hot.withValues(alpha: 0)],
        const [0, 0.6],
      ),
  );

  // Жерло: центр чуть ниже кромки окна, правее середины. Спад мягкий,
  // как exp(−2.3·d) в шейдере, — три ступени градиента его повторяют.
  canvas.drawRect(
    rect,
    Paint()
      ..blendMode = BlendMode.screen
      ..shader = _ellipse(
        Offset(w / 2 + h * 0.16, h * 1.12),
        h * 0.95,
        h * 0.95,
        [
          vent.withValues(alpha: 0.16),
          hot.withValues(alpha: 0.07),
          hot.withValues(alpha: 0),
        ],
        const [0, 0.38, 1],
      ),
  );
}

/// Эллиптический радиальный градиент: единичный круг, растянутый
/// матрицей. Так эллипс считается в шейдере, а не тесселируется
/// огромной окружностью.
ui.Shader _ellipse(
  Offset center,
  double rx,
  double ry,
  List<Color> colors,
  List<double> stops,
) {
  final matrix = Matrix4.translationValues(center.dx, center.dy, 0)
    ..multiply(Matrix4.diagonal3Values(rx, ry, 1));
  return ui.Gradient.radial(
    Offset.zero,
    1,
    colors,
    stops,
    TileMode.clamp,
    matrix.storage,
  );
}
