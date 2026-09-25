import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Линза: преломление фона под стеклом.
///
/// Шейдер работает фильтром фона (`ImageFilter.shader`), а такие фильтры
/// умеет только Impeller — на вебе и в тестах стекло остаётся матовым.
/// Проверять доступность нужно через [ready]: программа грузится асинхронно.
abstract final class EvGlassLens {
  static ui.FragmentProgram? _program;
  static Future<ui.FragmentProgram?>? _loading;

  /// Линза готова: движок умеет шейдерные фильтры и программа загружена.
  static final ValueNotifier<bool> ready = ValueNotifier<bool>(false);

  static ui.FragmentProgram? get program => _program;

  /// Поддерживается ли преломление этим движком вообще.
  static bool get supported => ui.ImageFilter.isShaderFilterSupported;

  /// Грузит программу один раз на приложение. Без Impeller не грузит
  /// ничего: шейдерный фильтр там всё равно бросит ошибку.
  static Future<ui.FragmentProgram?> load() {
    if (!supported) return Future<ui.FragmentProgram?>.value();
    return _loading ??= ui.FragmentProgram.fromAsset('shaders/glass_lens.frag')
        .then<ui.FragmentProgram?>((program) {
          _program = program;
          ready.value = true;
          return program;
        })
        .catchError((Object error) {
          debugPrint('EvGlass: шейдер линзы недоступен: $error');
          return null;
        });
  }
}

/// Фон под стеклом: размытие с цветом, а поверх — линза, если движок
/// её умеет.
///
/// Свой слой, а не `BackdropFilter`, по одной причине: шейдеру нужен
/// прямоугольник стекла в пикселях экрана, а стекло переезжает вместе
/// с прокруткой и параллаксом, не перерисовываясь. Слой пересчитывает
/// преобразование на каждой сборке сцены — так линза не отстаёт от кадра.
class EvGlassLensBackdrop extends SingleChildRenderObjectWidget {
  const EvGlassLensBackdrop({
    super.key,
    required this.radius,
    required this.blur,
    required this.color,
    required this.bevel,
    required this.depth,
    required this.dispersion,
    required this.devicePixelRatio,
    this.backdropKey,
    super.child,
  });

  final BorderRadius radius;

  /// Размытие фона, σ.
  final double blur;

  /// Цвет фона под стеклом: насыщенность и яркость. `null` — как есть.
  final ui.ColorFilter? color;

  final double bevel;
  final double depth;
  final double dispersion;
  final double devicePixelRatio;
  final BackdropKey? backdropKey;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderGlassLens(
    radius: radius,
    blur: blur,
    color: color,
    bevel: bevel,
    lensDepth: depth,
    dispersion: dispersion,
    devicePixelRatio: devicePixelRatio,
    backdropKey: backdropKey,
  );

  @override
  void updateRenderObject(BuildContext context, RenderGlassLens renderObject) {
    renderObject
      ..radius = radius
      ..blur = blur
      ..color = color
      ..bevel = bevel
      ..lensDepth = depth
      ..dispersion = dispersion
      ..devicePixelRatio = devicePixelRatio
      ..backdropKey = backdropKey;
  }
}

class RenderGlassLens extends RenderProxyBox {
  RenderGlassLens({
    required this._radius,
    required this._blur,
    required this._color,
    required this._bevel,
    required double lensDepth,
    required this._dispersion,
    required this._devicePixelRatio,
    required this._backdropKey,
  }) : _depth = lensDepth;

  BorderRadius _radius;
  BorderRadius get radius => _radius;
  set radius(BorderRadius value) {
    if (value == _radius) return;
    _radius = value;
    markNeedsPaint();
  }

  double _blur;
  double get blur => _blur;
  set blur(double value) {
    if (value == _blur) return;
    _blur = value;
    markNeedsPaint();
  }

  ui.ColorFilter? _color;
  ui.ColorFilter? get color => _color;
  set color(ui.ColorFilter? value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  double _bevel;
  double get bevel => _bevel;
  set bevel(double value) {
    if (value == _bevel) return;
    _bevel = value;
    markNeedsPaint();
  }

  double _depth;
  double get lensDepth => _depth;
  set lensDepth(double value) {
    if (value == _depth) return;
    _depth = value;
    markNeedsPaint();
  }

  double _dispersion;
  double get dispersion => _dispersion;
  set dispersion(double value) {
    if (value == _dispersion) return;
    _dispersion = value;
    markNeedsPaint();
  }

  double _devicePixelRatio;
  double get devicePixelRatio => _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  BackdropKey? _backdropKey;
  BackdropKey? get backdropKey => _backdropKey;
  set backdropKey(BackdropKey? value) {
    if (value == _backdropKey) return;
    _backdropKey = value;
    markNeedsPaint();
  }

  ui.FragmentShader? _shader;

  /// Прямоугольник стекла в координатах холста — тех же, в которых лежит
  /// слой. Прокрутка их не меняет: она двигает слой целиком.
  Rect _bounds = Rect.zero;

  final _clip = LayerHandle<ClipRRectLayer>();
  final _backdrop = LayerHandle<_LensLayer>();

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void dispose() {
    _clip.layer = null;
    _backdrop.layer = null;
    _shader?.dispose();
    _shader = null;
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) return;
    final bounds = Offset.zero & size;
    _bounds = offset & size;
    _clip.layer = context.pushClipRRect(
      needsCompositing,
      offset,
      bounds,
      _radius.toRRect(bounds),
      (context, offset) {
        final layer = _backdrop.layer ??= _LensLayer(this);
        layer.backdropKey = _backdropKey;
        context.pushLayer(layer, super.paint, offset);
      },
      oldLayer: _clip.layer,
    );
  }

  /// Размытие фона с ограничением выборки прямоугольником стекла —
  /// «bounded blur», та самая высокая выделка матового стекла в iOS:
  /// соседнее содержимое не затекает под кромку.
  ui.ImageFilter get _baseFilter {
    final blur = ui.ImageFilter.blur(
      sigmaX: _blur,
      sigmaY: _blur,
      bounds: _bounds,
    );
    final color = _color;
    return color == null
        ? blur
        : ui.ImageFilter.compose(outer: color, inner: blur);
  }

  /// Фильтр для текущего кадра и его подпись: пока подпись не меняется,
  /// слой остаётся у движка прежним.
  (ui.ImageFilter, Object) resolve(Layer layer) {
    final base = _baseFilter;
    final baseSignature = (_bounds, _blur, _color);
    final program = EvGlassLens.program;
    if (program == null || _bevel <= 0 || !_lensAllowed(layer)) {
      return (base, baseSignature);
    }
    final transform = getTransformTo(null);
    if (transform.storage.any((v) => !v.isFinite)) return (base, baseSignature);
    final rect = MatrixUtils.transformRect(transform, Offset.zero & size);
    if (rect.isEmpty) return (base, baseSignature);

    // Масштаб предков — прижатие при нажатии, «садящийся» экран при смене
    // раздела: скругление и кромка едут вместе с прямоугольником.
    final scale =
        math.min(rect.width / size.width, rect.height / size.height) *
        _devicePixelRatio;
    final frame = Rect.fromLTWH(
      rect.left * _devicePixelRatio,
      rect.top * _devicePixelRatio,
      rect.width * _devicePixelRatio,
      rect.height * _devicePixelRatio,
    );
    final radius = _radius.topLeft.x * scale;
    final bevel = math.min(
      _bevel * scale,
      math.min(frame.width, frame.height) / 2,
    );
    final signature = (
      frame,
      radius,
      bevel,
      _depth * scale,
      _dispersion,
      baseSignature,
    );
    final shader = _shader ??= program.fragmentShader();
    shader
      ..setFloat(2, frame.left)
      ..setFloat(3, frame.top)
      ..setFloat(4, frame.width)
      ..setFloat(5, frame.height)
      ..setFloat(6, radius)
      ..setFloat(7, bevel)
      ..setFloat(8, _depth * scale)
      ..setFloat(9, _dispersion)
      ..setFloat(10, 0);
    return (
      ui.ImageFilter.compose(outer: ui.ImageFilter.shader(shader), inner: base),
      signature,
    );
  }

  /// Шейдер получает фон в координатах экрана, поэтому он промахнётся
  /// мимо стекла, если выше по слоям кто-то открыл свой буфер: слой
  /// прозрачности при смене раздела, цветной фильтр, другое стекло.
  /// В таком кадре стекло остаётся матовым — это заметно меньше, чем
  /// преломление, съехавшее на полэкрана.
  static bool _lensAllowed(Layer layer) {
    for (Layer? l = layer.parent; l != null; l = l.parent) {
      if (l is OpacityLayer && (l.alpha ?? 255) < 255) return false;
      if (l is ColorFilterLayer ||
          l is ImageFilterLayer ||
          l is ShaderMaskLayer ||
          l is BackdropFilterLayer) {
        return false;
      }
    }
    return true;
  }
}

/// Слой фона, который пересобирает фильтр, если стекло уехало.
///
/// [updateSubtreeNeedsAddToScene] вызывается у каждого слоя перед сборкой
/// сцены — это единственное место, где дерево уже разложено и отрисовано,
/// а сцена ещё не собрана.
class _LensLayer extends BackdropFilterLayer {
  _LensLayer(this.glass);

  final RenderGlassLens glass;
  Object? _signature;

  @override
  void updateSubtreeNeedsAddToScene() {
    if (glass.attached) {
      final (next, signature) = glass.resolve(this);
      if (signature != _signature) {
        _signature = signature;
        filter = next;
        markNeedsAddToScene();
      }
    }
    super.updateSubtreeNeedsAddToScene();
  }
}
