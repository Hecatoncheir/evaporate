import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../atmosphere/film_grain.dart';
import 'glass_style.dart';

/// Свет для стекла: точка над плоскостью окна.
///
/// Источник света — курсор: на iOS блик на стекле ходит за наклоном
/// устройства, на столе такого наклона нет, зато есть курсор. Курсор берётся
/// тот же сглаженный, что двигает плюм и слои героя, поэтому стекло,
/// пар и обложка отвечают на одно движение.
///
/// Когда курсора нет (галерея, тесты, «уменьшить движение»), свет стоит
/// слева сверху — оттуда же, откуда горячий край у кнопки «Играть».
@immutable
class EvGlassLight {
  const EvGlassLight(this.point, this.height, this.attenuation);

  /// Где стоит свет — в координатах холста.
  final Offset point;

  /// На какой высоте над плоскостью. Чем ниже, тем резче блик ходит
  /// по кромке.
  final double height;

  /// Общая сила: у дальнего света блик слабее.
  final double attenuation;

  /// Направление по умолчанию — слева сверху.
  static const fallbackDirection = Offset(-0.62, -0.78);

  /// Свет для прямоугольника [rect]: курсор в [pointer] (доли окна),
  /// окно размером [window]. `null` вместо курсора — свет по умолчанию.
  factory EvGlassLight.of(Rect rect, Offset? pointer, Size window) {
    final reach = math.max(rect.shortestSide, 90.0) * 0.75;
    if (pointer == null) {
      final far = rect.longestSide * 1.4 + 200;
      return EvGlassLight(rect.center + fallbackDirection * far, reach, 0.78);
    }
    final point = Offset(pointer.dx * window.width, pointer.dy * window.height);
    final distance = (point - rect.center).distance;
    final near = math.max(0, distance - rect.longestSide / 2) / 700;
    return EvGlassLight(point, reach, 0.55 + 0.45 / (1 + near * near));
  }

  /// Насколько ярко светит на точку [p] с внешней нормалью [normal].
  ///
  /// Кромка стекла — четверть круга, поэтому нормаль к ней поднята над
  /// плоскостью: [_rimTilt] по горизонтали и [_rimLift] вверх.
  double intensity(Offset p, Offset normal) {
    final d = point - p;
    final len = math.sqrt(d.dx * d.dx + d.dy * d.dy + height * height);
    final dot =
        (d.dx * normal.dx * _rimTilt +
            d.dy * normal.dy * _rimTilt +
            height * _rimLift) /
        len;
    if (dot <= 0) return 0;
    return dot * dot * attenuation;
  }

  /// Единичное направление на свет из точки [p] — для заливок,
  /// которым хватает стороны.
  Offset directionFrom(Offset p) {
    final d = point - p;
    final len = d.distance;
    return len < 1e-3 ? fallbackDirection : d / len;
  }

  static const _rimTilt = 0.82;
  static const _rimLift = 0.57;
}

/// Поверхность стекла: заливка, зерно, внутреннее свечение и блик
/// на кромке. Содержимое рисуется между заливкой и бликом, поэтому
/// кромка никогда не уходит под текст.
class EvGlassSurface extends SingleChildRenderObjectWidget {
  const EvGlassSurface({
    super.key,
    required this.style,
    required this.fill,
    required this.radius,
    required this.keyLight,
    required this.pointer,
    required this.window,
    required this.hover,
    required this.press,
    this.rim,
    super.child,
  });

  /// Стороны, на которых светится кромка; `null` — весь периметр.
  final Set<AxisDirection>? rim;

  final EvGlassStyle style;

  /// Цвет заливки — уже с прозрачностью.
  final Color fill;

  final BorderRadius radius;

  /// Цвет блика: белый, подогретый акцентом облика. Тема задаёт
  /// температуру источника света — блик на стекле тоже.
  final Color keyLight;

  /// Курсор в долях окна; `null` — свет по умолчанию.
  final ValueListenable<Offset>? pointer;

  final Size window;

  /// Курсор внутри стекла — в его локальных координатах.
  final Offset? hover;

  /// Нажатие 0…1: стекло разгорается изнутри.
  final double press;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderGlassSurface(
    style: style,
    fill: fill,
    radius: radius,
    keyLight: keyLight,
    pointer: pointer,
    window: window,
    hover: hover,
    press: press,
    rim: rim,
  );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlassSurface renderObject,
  ) {
    renderObject
      ..style = style
      ..fill = fill
      ..radius = radius
      ..keyLight = keyLight
      ..pointer = pointer
      ..window = window
      ..hover = hover
      ..press = press
      ..rim = rim;
  }
}

class RenderGlassSurface extends RenderProxyBox {
  RenderGlassSurface({
    required this._style,
    required this._fill,
    required this._radius,
    required this._keyLight,
    required this._pointer,
    required this._window,
    required this._hover,
    required this._press,
    required this._rim,
  });

  Set<AxisDirection>? _rim;
  set rim(Set<AxisDirection>? value) {
    if (setEquals(value, _rim)) return;
    _rim = value;
    markNeedsPaint();
  }

  EvGlassStyle _style;
  EvGlassStyle get style => _style;
  set style(EvGlassStyle value) {
    if (value == _style) return;
    _style = value;
    markNeedsPaint();
  }

  Color _fill;
  Color get fill => _fill;
  set fill(Color value) {
    if (value == _fill) return;
    _fill = value;
    markNeedsPaint();
  }

  BorderRadius _radius;
  BorderRadius get radius => _radius;
  set radius(BorderRadius value) {
    if (value == _radius) return;
    _radius = value;
    markNeedsPaint();
  }

  Color _keyLight;
  Color get keyLight => _keyLight;
  set keyLight(Color value) {
    if (value == _keyLight) return;
    _keyLight = value;
    markNeedsPaint();
  }

  ValueListenable<Offset>? _pointer;
  ValueListenable<Offset>? get pointer => _pointer;
  set pointer(ValueListenable<Offset>? value) {
    if (value == _pointer) return;
    if (attached) _pointer?.removeListener(markNeedsPaint);
    _pointer = value;
    if (attached) _pointer?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  Size _window;
  Size get window => _window;
  set window(Size value) {
    if (value == _window) return;
    _window = value;
    markNeedsPaint();
  }

  Offset? _hover;
  Offset? get hover => _hover;
  set hover(Offset? value) {
    if (value == _hover) return;
    _hover = value;
    markNeedsPaint();
  }

  double _press;
  double get press => _press;
  set press(double value) {
    if (value == _press) return;
    _press = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _pointer?.addListener(markNeedsPaint);
    EvFilmGrain.revision.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _pointer?.removeListener(markNeedsPaint);
    EvFilmGrain.revision.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) {
      super.paint(context, offset);
      return;
    }
    final rect = offset & size;
    final rrect = _radius.toRRect(rect);
    final light = EvGlassLight.of(rect, _lightPointer(), _window);

    _paintBody(context.canvas, rect, rrect, light);
    super.paint(context, offset);
    // Холст берётся заново: если содержимое открыло свой слой — а внутри
    // стекла бывает другое стекло, — прежний холст уже закрыт.
    paintGlassRim(
      context.canvas,
      rrect,
      light,
      _style,
      _keyLight,
      press: _press,
      sides: _rim,
    );
  }

  /// Курсор в долях окна, приведённый к системе координат холста:
  /// стекло могло уехать параллаксом или прокруткой, поэтому свет
  /// пересчитывается через настоящее преобразование.
  Offset? _lightPointer() {
    final pointer = _pointer?.value;
    if (pointer == null) return null;
    final global = Offset(
      pointer.dx * _window.width,
      pointer.dy * _window.height,
    );
    final local = globalToLocal(global);
    if (local.dx.isNaN || local.dy.isNaN) return null;
    // Обратно в доли окна, но уже в координатах холста: на них считает
    // EvGlassLight.
    return Offset(
      local.dx / math.max(1, _window.width),
      local.dy / math.max(1, _window.height),
    );
  }

  void _paintBody(Canvas canvas, Rect rect, RRect rrect, EvGlassLight light) {
    canvas.drawRRect(rrect, Paint()..color = _fill);

    // Свет ложится на стекло сверху — тонкий вертикальный градиент,
    // тот же, что был у панелей.
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [
          const Color(0xFFFFFFFF).withValues(alpha: 0.045),
          const Color(0xFFFFFFFF).withValues(alpha: 0.012),
        ]),
    );

    final grain = _style.grain ? EvFilmGrain.image : null;
    if (grain != null) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = ImageShader(
            grain,
            TileMode.repeated,
            TileMode.repeated,
            Matrix4.identity().storage,
          )
          ..blendMode = BlendMode.overlay
          ..color = const Color(0x0D000000),
      );
    }

    // Внутреннее свечение от освещённой кромки вглубь стекла.
    if (_style.sheen > 0) {
      final dir = light.directionFrom(rect.center);
      final reach = rect.longestSide * 0.5;
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = ui.Gradient.linear(
            rect.center + dir * reach,
            rect.center - dir * reach * 0.4,
            [
              _keyLight.withValues(alpha: _style.sheen * light.attenuation),
              _keyLight.withValues(alpha: 0),
            ],
          ),
      );
    }

    // Стекло загорается там, где его трогают.
    final hover = _hover;
    if (hover != null && _style.glow > 0) {
      final center = hover + rect.topLeft;
      final radius = math.max(rect.shortestSide * 1.15, 54.0);
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = ui.Gradient.radial(
            center,
            radius,
            [
              _keyLight.withValues(alpha: _style.glow * (1 + _press * 0.8)),
              _keyLight.withValues(alpha: 0),
            ],
            const [0, 1],
          ),
      );
    }
  }
}

/// Блик на кромке: полоса в два ряда по периметру, яркость каждой точки
/// считается по её нормали и свету.
///
/// Полоса рисуется вершинами, а не обводкой: у обводки один цвет на всю
/// кромку, а стекло тем и отличается, что светится только повёрнутым
/// к свету краем, и ещё раз — противоположным, где свет выходит.
void paintGlassRim(
  Canvas canvas,
  RRect rrect,
  EvGlassLight light,
  EvGlassStyle style,
  Color keyLight, {
  double press = 0,
  Set<AxisDirection>? sides,
}) {
  if (sides != null) {
    // Кромка только на стыках: у каждой стороны своя открытая полоса.
    for (final side in sides) {
      _paintRim(
        canvas,
        _side(rrect.outerRect, side),
        light,
        style,
        keyLight,
        press: press,
        closed: false,
      );
    }
    return;
  }
  _paintRim(canvas, _perimeter(rrect), light, style, keyLight, press: press);
}

void _paintRim(
  Canvas canvas,
  List<(Offset, Offset)> samples,
  EvGlassLight light,
  EvGlassStyle style,
  Color keyLight, {
  required double press,
  bool closed = true,
}) {
  if (samples.length < 2) return;

  const outward = 0.6, peak = 0.3, inward = 1.6;
  final outer = <Offset>[];
  final mid = <Offset>[];
  final inner = <Offset>[];
  final glow = <Color>[];
  final clear = <Color>[];

  final back = Color.lerp(keyLight, const Color(0xFFFFFFFF), 0.7)!;
  for (final (p, n) in samples) {
    outer.add(p + n * outward);
    mid.add(p - n * peak);
    inner.add(p - n * inward);
    final key = light.intensity(p, n);
    final opposite = light.intensity(p, -n);
    final alpha =
        style.rimAmbient +
        style.rimKey * key * (1 + press * 0.5) +
        style.rimBack * opposite;
    glow.add(
      Color.lerp(
        back,
        keyLight,
        key.clamp(0.0, 1.0),
      )!.withValues(alpha: alpha.clamp(0.0, 1.0)),
    );
    clear.add(const Color(0x00FFFFFF));
  }

  // Вершины — нативный объект: его нужно закрыть сразу после отрисовки,
  // иначе сборщик мусора доберётся до него раньше, чем кадр доедет до
  // экрана, и холст упадёт на пустом указателе.
  final paint = Paint();
  for (final strip in [
    _strip(outer, mid, clear, glow, closed: closed),
    _strip(mid, inner, glow, clear, closed: closed),
  ]) {
    canvas.drawVertices(strip, BlendMode.dst, paint);
    strip.dispose();
  }
}

/// Лента треугольников между двумя рядами точек, замкнутая в кольцо.
ui.Vertices _strip(
  List<Offset> a,
  List<Offset> b,
  List<Color> ca,
  List<Color> cb, {
  bool closed = true,
}) {
  final points = <Offset>[];
  final colors = <Color>[];
  for (var i = 0; i < a.length + (closed ? 1 : 0); i++) {
    final j = i % a.length;
    points
      ..add(a[j])
      ..add(b[j]);
    colors
      ..add(ca[j])
      ..add(cb[j]);
  }
  return ui.Vertices(ui.VertexMode.triangleStrip, points, colors: colors);
}

/// Точки одной стороны прямоугольника с внешней нормалью.
List<(Offset, Offset)> _side(Rect r, AxisDirection side) {
  final (from, to, n) = switch (side) {
    AxisDirection.up => (r.topLeft, r.topRight, const Offset(0, -1)),
    AxisDirection.right => (r.topRight, r.bottomRight, const Offset(1, 0)),
    AxisDirection.down => (r.bottomLeft, r.bottomRight, const Offset(0, 1)),
    AxisDirection.left => (r.topLeft, r.bottomLeft, const Offset(-1, 0)),
  };
  // Как у периметра: длинную кромку дробим, чтобы свет гас вдоль неё.
  final steps = math.max(1, ((to - from).distance / 48).ceil());
  return [
    for (var i = 0; i <= steps; i++) (Offset.lerp(from, to, i / steps)!, n),
  ];
}

/// Точки периметра скруглённого прямоугольника с внешними нормалями,
/// по часовой стрелке от левого верхнего угла.
List<(Offset, Offset)> _perimeter(RRect r) {
  final radius = math
      .min(r.tlRadiusX, math.min(r.width, r.height) / 2)
      .clamp(0.0, math.min(r.width, r.height) / 2);
  final l = r.left, t = r.top, b = r.bottom, rt = r.right;
  final out = <(Offset, Offset)>[];

  void arc(Offset center, double from, double to) {
    // Дуга углом 90°: шаг в 9° держит кромку гладкой даже на радиусе 30.
    const steps = 10;
    for (var i = 0; i <= steps; i++) {
      final a = from + (to - from) * i / steps;
      final n = Offset(math.cos(a), math.sin(a));
      out.add((center + n * radius, n));
    }
  }

  void edge(Offset from, Offset to, Offset n) {
    // Длинную кромку дробим: точечный свет должен гаснуть вдоль неё.
    final steps = math.max(1, ((to - from).distance / 48).ceil());
    for (var i = 0; i <= steps; i++) {
      out.add((Offset.lerp(from, to, i / steps)!, n));
    }
  }

  const pi = math.pi;
  arc(Offset(l + radius, t + radius), pi, pi * 1.5);
  edge(Offset(l + radius, t), Offset(rt - radius, t), const Offset(0, -1));
  arc(Offset(rt - radius, t + radius), pi * 1.5, pi * 2);
  edge(Offset(rt, t + radius), Offset(rt, b - radius), const Offset(1, 0));
  arc(Offset(rt - radius, b - radius), 0, pi * 0.5);
  edge(Offset(rt - radius, b), Offset(l + radius, b), const Offset(0, 1));
  arc(Offset(l + radius, b - radius), pi * 0.5, pi);
  edge(Offset(l, b - radius), Offset(l, t + radius), const Offset(-1, 0));
  return out;
}
