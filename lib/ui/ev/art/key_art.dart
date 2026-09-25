import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

/// Палитра ключевого кадра. Обложки рисуются процедурно: у раздачи картинки
/// может не быть, а серый прямоугольник на полке — худшее, что можно
/// показать вместо игры.
@immutable
class EvCoverPalette {
  const EvCoverPalette(this.deep, this.mid, this.mid2, this.hot, this.hot2);

  /// Верх неба.
  final Color deep;

  /// Середина неба.
  final Color mid;

  /// Средний слой дымки.
  final Color mid2;

  /// Свет: ядро, кромки хребтов.
  final Color hot;

  /// Белое каление: центр ядра, лучи, дальняя дымка.
  final Color hot2;

  static const ash = EvCoverPalette(
    Color(0xFF2A0F06),
    Color(0xFF160806),
    Color(0xFF7A2A0C),
    Color(0xFFFF7A18),
    Color(0xFFFFD28A),
  );
  static const deepSea = EvCoverPalette(
    Color(0xFF04222C),
    Color(0xFF03121A),
    Color(0xFF0B4D5E),
    Color(0xFF33D6D0),
    Color(0xFFC8FFF6),
  );
  static const neon = EvCoverPalette(
    Color(0xFF1B0636),
    Color(0xFF0D0320),
    Color(0xFF4A108C),
    Color(0xFFC15BFF),
    Color(0xFFFFB6F2),
  );
  static const lunar = EvCoverPalette(
    Color(0xFF0A1430),
    Color(0xFF050A1C),
    Color(0xFF1F3A7A),
    Color(0xFF6F9BFF),
    Color(0xFFDCE8FF),
  );
  static const crimson = EvCoverPalette(
    Color(0xFF2E0610),
    Color(0xFF170309),
    Color(0xFF7D0D22),
    Color(0xFFFF3D5E),
    Color(0xFFFFC0C8),
  );
  static const glass = EvCoverPalette(
    Color(0xFF0B2A22),
    Color(0xFF04130F),
    Color(0xFF14624A),
    Color(0xFF3BE39B),
    Color(0xFFD3FFE9),
  );
  static const wolf = EvCoverPalette(
    Color(0xFF231A08),
    Color(0xFF120D04),
    Color(0xFF6B5010),
    Color(0xFFFFC24D),
    Color(0xFFFFF0C4),
  );
  static const orbit = EvCoverPalette(
    Color(0xFF0A0620),
    Color(0xFF050313),
    Color(0xFF2E1A7A),
    Color(0xFF8F6BFF),
    Color(0xFFD8CCFF),
  );
  static const threshold = EvCoverPalette(
    Color(0xFF231226),
    Color(0xFF100815),
    Color(0xFF5C2A63),
    Color(0xFFFF7AD9),
    Color(0xFFFFD6F4),
  );
  static const storm = EvCoverPalette(
    Color(0xFF04182C),
    Color(0xFF020C18),
    Color(0xFF0D4A7A),
    Color(0xFF5EE7FF),
    Color(0xFFD6F8FF),
  );
}

/// Генератор прототипа — mulberry32 с арифметикой 32-битных целых JS.
///
/// Тот же сид даёт ту же последовательность, что `rng32` в макете, поэтому
/// обложки и герой в приложении — те же кадры, а не похожие. Умножение
/// собрано из 16-битных половин: в вебе `int` — это double, и прямое
/// произведение двух 32-битных чисел потеряло бы младшие разряды.
class EvArtRandom {
  EvArtRandom(int seed) : _state = seed & _mask;

  static const _mask = 0xFFFFFFFF;

  int _state;

  /// Следующее число в [0, 1).
  double next() {
    _state = (_state + 0x6D2B79F5) & _mask;
    var t = _imul(_state ^ (_state >>> 15), 1 | _state);
    t = ((t + _imul(t ^ (t >>> 7), 61 | t)) & _mask) ^ t;
    return ((t ^ (t >>> 14)) & _mask) / 4294967296;
  }

  static int _imul(int a, int b) {
    final low = (a & 0xFFFF) * (b & 0xFFFF);
    final high =
        ((a >>> 16) & 0xFFFF) * (b & 0xFFFF) +
        (a & 0xFFFF) * ((b >>> 16) & 0xFFFF);
    return (low + ((high << 16) & _mask)) & _mask;
  }
}

const _clear = Color(0x00000000);
const _ink = Color(0xFF020205);

/// Сцена ключевого кадра — перенос `paintScene` из прототипа, шаг в шаг:
/// небо, три октавы дымки, световое ядро, лучи, звёзды, хребты, монолит
/// и виньетка. Случайные числа берутся в том же порядке, что в макете.
///
/// [sunX] и [sunY] — положение ядра в долях кадра; без них оно случайное.
/// Обложка — `ridges: 2`, небо героя — `ridges: 0, monolith: false`.
void paintKeyScene(
  Canvas canvas,
  Size size,
  EvCoverPalette palette,
  int seed, {
  int ridges = 3,
  bool monolith = true,
  double? sunX,
  double? sunY,
}) {
  final w = size.width, h = size.height;
  final rnd = EvArtRandom(seed);
  final full = Offset.zero & size;

  // 1 · небо
  canvas.drawRect(
    full,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(w * .3, h),
        [palette.deep, palette.mid, const Color(0xFF040407)],
        const [0, .48, 1],
      ),
  );

  // 2 · объёмная дымка: шум в несколько клеток, растянутый на кадр
  // с размытием, — дёшево и даёт ровно ту объёмную мглу, что нужна
  for (final (cells, alpha, tint) in [
    (7, .30, palette.hot),
    (19, .20, palette.mid2),
    (52, .11, palette.hot2),
  ]) {
    final rows = math.max(4, (cells * h / w).round());
    final noise = _noise(cells, rows, rnd);
    final sigma = (w / cells / 2.1).roundToDouble();
    canvas.saveLayer(
      full,
      Paint()
        ..blendMode = BlendMode.screen
        ..color = Color.fromRGBO(0, 0, 0, alpha)
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.decal,
        ),
    );
    canvas.drawImageRect(
      noise,
      Rect.fromLTWH(0, 0, cells.toDouble(), rows.toDouble()),
      full,
      Paint()..filterQuality = FilterQuality.low,
    );
    canvas.restore();
    noise.dispose();
    canvas.drawRect(
      full,
      Paint()
        ..blendMode = BlendMode.overlay
        ..color = tint.withValues(alpha: alpha * .6),
    );
  }

  // 3 · световое ядро
  final sx = w * (sunX ?? (.24 + rnd.next() * .5));
  final sy = h * (sunY ?? (.28 + rnd.next() * .24));
  final sr = w * (.10 + rnd.next() * .14);
  canvas.drawCircle(
    Offset(sx, sy),
    sr * 4.2,
    Paint()
      ..blendMode = BlendMode.screen
      ..shader = ui.Gradient.radial(
        Offset(sx, sy),
        sr * 4.2,
        [const Color(0xFFFFFFFF), palette.hot2, palette.hot, _clear, _clear],
        const [0, .10, .34, .7, 1],
      ),
  );

  // 4 · лучи от ядра; прозрачность холста (20 %) — в цветах градиента
  for (var i = 0; i < 5; i++) {
    canvas
      ..save()
      ..translate(sx, sy)
      ..rotate((rnd.next() - .5) * 1.5 + math.pi / 2);
    final left = -w * (.02 + rnd.next() * .05);
    final right = w * (.02 + rnd.next() * .06);
    canvas
      ..drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(left, h * 1.5)
          ..lineTo(right, h * 1.5)
          ..close(),
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h * 1.5), [
            palette.hot2.withValues(alpha: .2),
            _clear,
          ]),
      )
      ..restore();
  }

  // 5 · звёзды
  final star = Paint()..blendMode = BlendMode.screen;
  for (var i = 0; i < 90; i++) {
    star.color = Color.fromRGBO(255, 255, 255, rnd.next() * .55);
    canvas.drawRect(
      Rect.fromLTWH(rnd.next() * w, rnd.next() * h * .6, 1.1, 1.1),
      star,
    );
  }

  // 6 · хребты: силуэт горизонта с подсвеченной кромкой
  for (var r = 0; r < ridges; r++) {
    final base = h * (.58 + r * .11);
    final amp = h * (.16 - r * .035);
    final step = w / 34;
    final path = Path()..moveTo(-4, h + 4);
    final ph = rnd.next() * 9;
    for (var x = -4.0; x <= w + 4; x += step) {
      path.lineTo(
        x,
        base +
            math.sin(x / w * 6.1 + ph) * amp * .6 +
            math.sin(x / w * 15.3 + ph * 2) * amp * .34 +
            math.sin(x / w * 31 + ph * 3) * amp * .12,
      );
    }
    path
      ..lineTo(w + 4, h + 4)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = switch (r) {
          0 => const Color.fromRGBO(4, 4, 8, .72),
          1 => const Color.fromRGBO(3, 3, 6, .88),
          _ => _ink,
        },
    );
    _glowStroke(canvas, path, palette.hot, .42 - r * .11, 1.4, 12);
  }

  // 7 · монолит — одна жёсткая вертикаль задаёт масштаб
  if (monolith) {
    final mw = w * .035, mx = w * (.62 + rnd.next() * .16), mh = h * .34;
    final top = h * .72 - mh;
    final rim = Rect.fromLTWH(mx, top, mw * .32, mh);
    // Тень холста: форма цвета тени с альфой градиента, размытая
    // на shadowBlur / 2. Прозрачность холста (75 %) — в цветах.
    canvas
      ..saveLayer(
        null,
        Paint()
          ..blendMode = BlendMode.screen
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: 13,
            sigmaY: 13,
            tileMode: TileMode.decal,
          ),
      )
      ..drawRect(
        rim,
        Paint()
          ..shader = ui.Gradient.linear(Offset(mx, top), Offset(mx, h * .72), [
            palette.hot.withValues(alpha: .75),
            palette.hot.withValues(alpha: 0),
          ]),
      )
      ..restore()
      ..drawRect(
        rim,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = ui.Gradient.linear(Offset(mx, top), Offset(mx, h * .72), [
            palette.hot2.withValues(alpha: .75),
            _clear,
          ]),
      )
      ..drawRect(
        Rect.fromLTWH(mx - mw * .5, h * .72 - mh * .96, mw, mh * .96),
        Paint()..color = _ink,
      );
  }

  // 8 · виньетка — двухточечный радиальный градиент, как у холста
  canvas.drawRect(
    full,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset(w * .5, h * .5),
        h * 1.15,
        const [_clear, Color.fromRGBO(2, 2, 5, .86)],
        const [0, 1],
        TileMode.clamp,
        null,
        Offset(w * .5, h * .42),
        h * .2,
      ),
  );
}

/// Средний слой героя: два хребта ближе неба, с горячей кромкой.
void paintHeroRidges(
  Canvas canvas,
  Size size,
  EvCoverPalette palette,
  int seed,
) {
  final w = size.width, h = size.height;
  final rnd = EvArtRandom(seed + 11);
  for (var r = 0; r < 2; r++) {
    final base = h * (.60 + r * .13), amp = h * (.15 - r * .04);
    final ph = rnd.next() * 9;
    final path = Path()..moveTo(-4, h + 4);
    for (var x = -4.0; x <= w + 4; x += w / 40) {
      path.lineTo(
        x,
        base +
            math.sin(x / w * 5.4 + ph) * amp * .7 +
            math.sin(x / w * 13 + ph * 2) * amp * .3,
      );
    }
    path
      ..lineTo(w + 4, h + 4)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = r == 0 ? const Color.fromRGBO(5, 5, 9, .8) : _ink,
    );
    _glowStroke(canvas, path, palette.hot, .5 - r * .18, 1.6, 16);
  }
}

/// Передний слой обложки в карточке игры: тёплое ядро, два гребня
/// с горячей кромкой и россыпь искр над ними. Перенос второго холста
/// `sheetLayers` из прототипа; небо там же рисует [paintKeyScene]
/// с ядром в точке (0.64, 0.34) и без хребтов.
void paintSheetWaves(
  Canvas canvas,
  Size size,
  EvCoverPalette palette,
  int seed,
) {
  final w = size.width, h = size.height;
  final rnd = EvArtRandom(seed + 91);

  // ядро за гребнями
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..blendMode = BlendMode.screen
      ..shader = ui.Gradient.radial(
        Offset(w * .64, h * .52),
        w * .2,
        [
          palette.hot2.withValues(alpha: .4),
          palette.hot.withValues(alpha: .4),
          palette.hot.withValues(alpha: 0),
        ],
        const [0, .42, 1],
      ),
  );

  for (var k = 0; k < 2; k++) {
    final base = h * (.66 + k * .14), amp = h * .16;
    final ph = rnd.next() * 9;
    final path = Path()..moveTo(-2, h + 2);
    for (var x = -2.0; x <= w + 2; x += w / 30) {
      path.lineTo(
        x,
        base +
            math.sin(x / w * 5.2 + ph) * amp * .7 +
            math.sin(x / w * 13 + ph * 2) * amp * .3,
      );
    }
    path
      ..lineTo(w + 2, h + 2)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = k == 0
            ? const Color.fromRGBO(4, 4, 8, .8)
            : const Color(0xFF010104),
    );
    _glowStroke(canvas, path, palette.hot, .46 - k * .2, 1.5, 14);
  }

  // искры над гребнями
  final spark = Paint()..blendMode = BlendMode.screen;
  for (var i = 0; i < 60; i++) {
    spark.color = Color.fromRGBO(255, 236, 206, rnd.next() * .5);
    canvas.drawCircle(
      Offset(rnd.next() * w, h * .3 + rnd.next() * h * .66),
      rnd.next() * 2 + .5,
      spark,
    );
  }
}

/// Передний слой героя: одинокая фигура на уступе даёт масштаб и сюжет,
/// за ней свечение, перед ней пылинки.
void paintHeroLedge(
  Canvas canvas,
  Size size,
  EvCoverPalette palette,
  int seed,
) {
  final w = size.width, h = size.height;
  final rnd = EvArtRandom(seed + 29);

  // Свечение — круг радиуса градиента; прозрачность холста (45 %) —
  // в цветах. В прототипе градиент заливал прямоугольник от 0,4 высоты,
  // и его верх резал круг: в небе стояла горизонтальная ступенька.
  canvas.drawCircle(
    Offset(w * .70, h * .70),
    w * .22,
    Paint()
      ..blendMode = BlendMode.screen
      ..shader = ui.Gradient.radial(
        Offset(w * .70, h * .70),
        w * .22,
        [
          palette.hot2.withValues(alpha: .45),
          palette.hot.withValues(alpha: .45),
          _clear,
        ],
        const [0, .4, 1],
      ),
  );

  final silhouette = Paint()..color = const Color(0xFF010104);
  canvas.drawPath(
    Path()
      ..moveTo(w * .50, h + 4)
      ..lineTo(w * .545, h * .815)
      ..lineTo(w * .74, h * .795)
      ..lineTo(w * .86, h * .86)
      ..lineTo(w + 4, h * .845)
      ..lineTo(w + 4, h + 4)
      ..close(),
    silhouette,
  );
  final fx = w * .695, fy = h * .795, s = h * .105;
  canvas
    ..drawOval(
      Rect.fromCenter(
        center: Offset(fx, fy - s * .86),
        width: s * .20,
        height: s * .24,
      ),
      silhouette,
    )
    ..drawPath(
      Path()
        ..moveTo(fx - s * .15, fy - s * .74)
        ..lineTo(fx + s * .17, fy - s * .74)
        ..lineTo(fx + s * .22, fy)
        ..lineTo(fx - s * .20, fy)
        ..close(),
      silhouette,
    );

  final mote = Paint()..blendMode = BlendMode.screen;
  for (var i = 0; i < 70; i++) {
    mote.color = Color.fromRGBO(255, 235, 200, rnd.next() * .5);
    final radius = rnd.next() * 2.1 + .5;
    canvas.drawCircle(
      Offset(rnd.next() * w, h * .35 + rnd.next() * h * .62),
      radius,
      mote,
    );
  }
}

/// Обводка со свечением, как `shadowBlur` холста: размытая копия цвета тени
/// под самой линией. Сигма гауссианы у холста — половина `shadowBlur`.
void _glowStroke(
  Canvas canvas,
  Path path,
  Color color,
  double alpha,
  double width,
  double shadowBlur,
) {
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..blendMode = BlendMode.screen
    ..color = color.withValues(alpha: alpha);
  canvas
    ..drawPath(
      path,
      paint..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowBlur / 2),
    )
    ..drawPath(path, paint..maskFilter = null);
}

/// Серый шум из [cells] × [rows] пикселей, по пикселю на случайное число —
/// в порядке строк, как `putImageData` в прототипе. Рисуется одним вызовом
/// треугольников, без сглаживания краёв.
ui.Image _noise(int cells, int rows, EvArtRandom rnd) {
  final count = cells * rows;
  final positions = Float32List(count * 12);
  final colors = Int32List(count * 6);
  for (var i = 0; i < count; i++) {
    final x = (i % cells).toDouble(), y = (i ~/ cells).toDouble();
    final v = (rnd.next() * 255).floor();
    final argb = 0xFF000000 | (v << 16) | (v << 8) | v;
    positions.setAll(i * 12, [
      x, y, x + 1, y, x, y + 1, //
      x + 1, y, x + 1, y + 1, x, y + 1,
    ]);
    colors.fillRange(i * 6, i * 6 + 6, argb.toSigned(32));
  }
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawVertices(
    ui.Vertices.raw(VertexMode.triangles, positions, colors: colors),
    BlendMode.dst,
    Paint(),
  );
  final picture = recorder.endRecording();
  final image = picture.toImageSync(cells, rows);
  picture.dispose();
  return image;
}
