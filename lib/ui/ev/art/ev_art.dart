import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'key_art.dart';

/// Слой ключевого кадра героя. Глубина — сдвиг в пикселях за курсором,
/// запас — насколько слой шире героя с каждой стороны, чтобы сдвиг не
/// открывал края. Всё из прототипа: `.hl.sky{inset:-9%}`, `data-d`.
enum EvHeroLayer {
  sky(bleed: .09, depth: 5),
  ridges(bleed: .06, depth: 14),
  ledge(bleed: .06, depth: 30);

  const EvHeroLayer({required this.bleed, required this.depth});

  final double bleed;
  final double depth;

  /// Кадр героя рисуется в координатах 1280 × 720, как холсты прототипа.
  static const scene = Size(1280, 720);

  void paint(Canvas canvas, EvCoverPalette palette, int seed) => switch (this) {
    sky => paintKeyScene(
      canvas,
      scene,
      palette,
      seed,
      ridges: 0,
      monolith: false,
      sunX: .68,
      sunY: .34,
    ),
    ridges => paintHeroRidges(canvas, scene, palette, seed),
    ledge => paintHeroLedge(canvas, scene, palette, seed),
  };
}

/// Слой обложки в карточке игры. Кадр шире карточки на 5 % с каждой
/// стороны и ходит за курсором на 6 и 22 px — `.sheet-art .sl` и
/// `data-d` в прототипе.
enum EvSheetLayer {
  sky(depth: 6),
  waves(depth: 22);

  const EvSheetLayer({required this.depth});

  final double depth;

  /// Запас с каждой стороны — `inset:-5%`.
  static const bleed = .05;

  /// Холст карточки в прототипе — 1100 × 420.
  static const scene = Size(1100, 420);

  void paint(Canvas canvas, EvCoverPalette palette, int seed) => switch (this) {
    sky => paintKeyScene(
      canvas,
      scene,
      palette,
      seed + 3,
      ridges: 0,
      monolith: false,
      sunX: .64,
      sunY: .34,
    ),
    waves => paintSheetWaves(canvas, scene, palette, seed),
  };
}

/// Растры ключевых кадров.
///
/// Процедурный кадр дорог: три размытых слоя шума, свечения, сотня звёзд.
/// Под Impeller кэша растра нет, и кадр, нарисованный прямо в дереве,
/// перерисовывался бы на каждом кадре окна, а атмосфера идёт на 60 к/с.
/// Поэтому кадр один раз рисуется в текстуру нужного размера — как холст
/// прототипа в `toDataURL`, — а дальше рисуется текстура.
///
/// Картинки берутся из кэша на время одного рисования и не хранятся:
/// вытесненная из кэша картинка остаётся жива, пока её держит слой кадра.
abstract final class EvArtCache {
  // Литерал карты помнит порядок вставки: первой вытесняется самая
  // давно нужная картинка.
  static final _covers = <Object, ui.Image>{};
  static final _heroLayers = <Object, ui.Image>{};
  static final _sheetLayers = <Object, ui.Image>{};
  static final _banners = <Object, ui.Image>{};

  /// Обложки: полка, продолжение, палитра, загрузки — с запасом на смену
  /// размеров окна.
  static const _coverCapacity = 96;

  /// Слои героя: три слоя на пару масштабов.
  static const _heroCapacity = 6;

  /// Карточка открыта одна, и слоёв в ней два — с запасом на ступень
  /// масштаба при перетаскивании края окна.
  static const _sheetCapacity = 4;

  /// Шапка страницы одна на экран — с запасом на ступень масштаба.
  static const _bannerCapacity = 3;

  /// Обложка — сцена 300 × 400 прототипа в текстуре [width] × [height].
  static ui.Image cover(
    EvCoverPalette palette,
    int seed,
    int width,
    int height,
  ) => _lookup(
    _covers,
    (palette, seed, width, height),
    _coverCapacity,
    () => _rasterize(
      evCoverScene,
      width,
      height,
      (canvas) => paintKeyScene(canvas, evCoverScene, palette, seed, ridges: 2),
    ),
  );

  /// Слой героя: сцена 1280 × 720 с масштабом [scale].
  static ui.Image heroLayer(
    EvHeroLayer layer,
    EvCoverPalette palette,
    int seed,
    double scale,
  ) => _lookup(
    _heroLayers,
    (layer, palette, seed, scale),
    _heroCapacity,
    () => _rasterize(
      EvHeroLayer.scene,
      (EvHeroLayer.scene.width * scale).round(),
      (EvHeroLayer.scene.height * scale).round(),
      (canvas) => layer.paint(canvas, palette, seed),
    ),
  );

  /// Слой карточки игры: сцена 1100 × 420 с масштабом [scale].
  static ui.Image sheetLayer(
    EvSheetLayer layer,
    EvCoverPalette palette,
    int seed,
    double scale,
  ) => _lookup(
    _sheetLayers,
    (layer, palette, seed, scale),
    _sheetCapacity,
    () => _rasterize(
      EvSheetLayer.scene,
      (EvSheetLayer.scene.width * scale).round(),
      (EvSheetLayer.scene.height * scale).round(),
      (canvas) => layer.paint(canvas, palette, seed),
    ),
  );

  /// Широкий кадр шапки: сцена 1400 × 460 с масштабом [scale].
  static ui.Image banner(EvBanner banner, double scale) => _lookup(
    _banners,
    (banner, scale),
    _bannerCapacity,
    () => _rasterize(
      evBannerScene,
      (evBannerScene.width * scale).round(),
      (evBannerScene.height * scale).round(),
      (canvas) => paintKeyScene(
        canvas,
        evBannerScene,
        banner.palette,
        banner.seed,
        ridges: 2,
        sunX: banner.sunX,
        sunY: banner.sunY,
      ),
    ),
  );

  /// Сколько растров сейчас в кэше.
  @visibleForTesting
  static int get length =>
      _covers.length +
      _heroLayers.length +
      _sheetLayers.length +
      _banners.length;

  @visibleForTesting
  static void clear() {
    for (final image in [
      ..._covers.values,
      ..._heroLayers.values,
      ..._sheetLayers.values,
      ..._banners.values,
    ]) {
      image.dispose();
    }
    _covers.clear();
    _heroLayers.clear();
    _sheetLayers.clear();
    _banners.clear();
  }

  static ui.Image _lookup(
    Map<Object, ui.Image> images,
    Object key,
    int capacity,
    ui.Image Function() make,
  ) {
    final hit = images.remove(key);
    if (hit != null) return images[key] = hit;
    while (images.length >= capacity) {
      images.remove(images.keys.first)!.dispose();
    }
    return images[key] = make();
  }

  static ui.Image _rasterize(
    Size scene,
    int width,
    int height,
    void Function(Canvas canvas) paint,
  ) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(width / scene.width, height / scene.height);
    paint(canvas);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(width, height);
    picture.dispose();
    return image;
  }
}

/// Широкий кадр под шапкой страницы — профиль, профиль друга: палитра
/// игры, зерно и где стоит солнце. `makeArt(1400, 460, …, {ridges: 2})`
/// в прототипе.
typedef EvBanner = ({
  EvCoverPalette palette,
  int seed,
  double sunX,
  double sunY,
});

/// Холст шапки в прототипе.
const evBannerScene = Size(1400, 460);

/// Шапка страницы: кадр заполняет свой размер по `background-size: cover`.
/// Растр берётся ступенями в четверть масштаба, чтобы перетаскивание края
/// окна не рисовало сцену заново на каждом кадре.
class EvBannerArt extends StatelessWidget {
  const EvBannerArt(this.banner, {super.key});

  final EvBanner banner;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _BannerPainter(banner, MediaQuery.devicePixelRatioOf(context)),
    size: Size.infinite,
  );
}

class _BannerPainter extends CustomPainter {
  _BannerPainter(this.banner, this.devicePixelRatio);

  final EvBanner banner;
  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final fit = math.max(
      size.width / evBannerScene.width,
      size.height / evBannerScene.height,
    );
    final scale = (fit * devicePixelRatio * 4).ceil().clamp(1, 12) / 4;
    final image = EvArtCache.banner(banner, scale);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(
        center: size.center(Offset.zero),
        width: evBannerScene.width * fit,
        height: evBannerScene.height * fit,
      ),
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(_BannerPainter old) =>
      old.banner != banner || old.devicePixelRatio != devicePixelRatio;
}

/// Сцена обложки в прототипе — холст 300 × 400.
const evCoverScene = Size(300, 400);

/// Обложка игры: процедурный кадр из растрового кэша. Заполняет свой
/// размер по правилу `background-size: cover` — сцена 3 : 4 масштабируется
/// по большей стороне и обрезается по центру.
class EvCover extends LeafRenderObjectWidget {
  const EvCover({super.key, required this.palette, required this.seed});

  final EvCoverPalette palette;
  final int seed;

  @override
  RenderEvCover createRenderObject(BuildContext context) => RenderEvCover(
    palette: palette,
    seed: seed,
    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
  );

  @override
  void updateRenderObject(BuildContext context, RenderEvCover renderObject) =>
      renderObject
        ..palette = palette
        ..seed = seed
        ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
}

class RenderEvCover extends RenderBox {
  RenderEvCover({
    required this._palette,
    required this._seed,
    required this._devicePixelRatio,
  });

  EvCoverPalette _palette;
  set palette(EvCoverPalette value) {
    if (value == _palette) return;
    _palette = value;
    markNeedsPaint();
  }

  int _seed;
  set seed(int value) {
    if (value == _seed) return;
    _seed = value;
    markNeedsPaint();
  }

  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.hasBoundedWidth && constraints.hasBoundedHeight
      ? constraints.biggest
      : constraints.constrain(evCoverScene);

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) return;
    final dpr = _devicePixelRatio;
    final fit = math.max(
      size.width / evCoverScene.width,
      size.height / evCoverScene.height,
    );
    final width = math.max(1, (evCoverScene.width * fit * dpr).round());
    final height = math.max(1, (evCoverScene.height * fit * dpr).round());
    final image = EvArtCache.cover(_palette, _seed, width, height);
    context.canvas.drawImageRect(
      image,
      Rect.fromCenter(
        center: Offset(width / 2, height / 2),
        width: math.min(width.toDouble(), size.width * dpr),
        height: math.min(height.toDouble(), size.height * dpr),
      ),
      offset & size,
      Paint()..filterQuality = FilterQuality.low,
    );
  }
}
