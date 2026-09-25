import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../art/ev_art.dart';
import '../art/key_art.dart';
import '../atmosphere/ev_atmosphere.dart';
import '../design/effects.dart';
import '../design/theme.dart';
import '../returning/ev_return_widgets.dart';
import '../widgets/ev_controls.dart';
import '../widgets/ev_icon.dart';
import '../widgets/ev_play_button.dart';
import '../widgets/ev_surfaces.dart';
import 'hero_cta.dart';
import 'hero_state.dart';
import 'library_layout.dart';

/// Чип героя: подпись и горячий ли он. Горячий — состояние игры, первым.
typedef EvHeroChip = (String label, bool hot);

/// Герой библиотеки: ключевой кадр игры, на которой вы остановились,
/// и кнопка, которая её продолжает.
///
/// Кадр — три слоя глубины (небо, хребты, уступ с фигурой), каждый
/// сдвигается за курсором на свою глубину: 5, 14 и 30 px. Текст идёт
/// против них на 8 px. Курсор — общий с плюмом, из [EvAtmosphere].
/// Параллакс выключается в «Настройках → Эффекты» и при «уменьшить
/// движение».
///
/// Пока «Играть» заряжается, кадр дрожит тепловым маревом, как фильтр
/// `#shimmer` в прототипе.
class EvHero extends StatefulWidget {
  const EvHero({
    super.key,
    required this.layout,
    required this.palette,
    required this.seed,
    required this.title,
    required this.content,
    this.state = EvHeroState.ready,
    this.onLaunch,
    this.onDetails,
    this.onInstall,
    this.onQuit,
    this.onOverlay,
    this.onOtherSave,
  });

  final EvLibraryLayout layout;
  final EvCoverPalette palette;
  final int seed;

  /// Название. Последнее слово набирается жирным отдельной строкой.
  final String title;

  /// Что герой говорит об игре в этом состоянии.
  final EvHeroContent content;

  /// Состояние игры: оно решает, что стоит на месте «Играть».
  final EvHeroState state;

  /// Удержание «Играть» дошло до конца.
  final VoidCallback? onLaunch;

  /// «Подробнее». `null` — карточки игры ещё нет, кнопка не нажимается.
  final VoidCallback? onDetails;

  /// «Установить» и «Обновить и играть».
  final VoidCallback? onInstall;

  /// «Завершить» — игра закончилась.
  final VoidCallback? onQuit;

  /// «Оверлей» поверх игры.
  final VoidCallback? onOverlay;

  /// «Другое» у точки сохранения — выбрать другую.
  final VoidCallback? onOtherSave;

  @override
  State<EvHero> createState() => _EvHeroState();
}

class _EvHeroState extends State<EvHero> {
  final _charge = ValueNotifier<double>(0);
  final _clock = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    // Ширина описания считается от знака «0» шрифта, а шрифты догружаются
    // после первого кадра: без пересчёта строка осталась бы мерой запасного
    // шрифта, и описание переносилось бы на лишнюю строку.
    PaintingBinding.instance.systemFonts.addListener(_onFontsLoaded);
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_onFontsLoaded);
    _charge.dispose();
    super.dispose();
  }

  void _onFontsLoaded() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final m = widget.layout;
    final effects = EvEffectsScope.maybeOf(context);
    final still = MediaQuery.disableAnimationsOf(context);
    final pointer = (effects?.parallax ?? false) && !still
        ? EvAtmosphere.pointerOf(context)
        : null;

    return SizedBox(
      height: m.heroHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.sub,
          borderRadius: ev.radii.b5,
          border: Border.all(color: c.line),
        ),
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(math.max(0, ev.radii.r5 - 1)),
            child: LayoutBuilder(
              builder: (context, box) => Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: EvHeroArtPainter(
                        palette: widget.palette,
                        seed: widget.seed,
                        devicePixelRatio: MediaQuery.devicePixelRatioOf(
                          context,
                        ),
                        pointer: pointer,
                        charge: still ? null : _charge,
                        clock: _clock,
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: CustomPaint(painter: _GradePainter(c.sub)),
                  ),
                  Positioned(
                    left: m.bodySide,
                    right: m.bodySide,
                    bottom: m.bodyBottom,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: m.bodyMaxWidth(box.maxWidth),
                        ),
                        child: _Depth(
                          pointer: pointer,
                          depth: -8,
                          child: RepaintBoundary(child: _body(context)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Что стоит на месте «Играть» в этом состоянии.
  ///
  /// Установленную игру держат, у не установленной на том же месте
  /// «Установить», у обновляемой — две кнопки, во время установки —
  /// прогресс, а у запущенной кнопка становится статусом.
  List<Widget> _cta(BuildContext context, EvEffects? effects) {
    final m = widget.layout;
    final content = widget.content;

    if (content.install != null) {
      return [EvInstallBox(content.install!)];
    }
    if (content.runningFor != null) {
      return [
        EvRunningPill(content.runningFor!, height: m.buttonHeight),
        EvGhostButton(
          label: 'Оверлей',
          icon: EvIcons.library,
          height: m.buttonHeight,
          grouped: true,
          onPressed: widget.onOverlay,
        ),
        EvGhostButton(
          label: 'Завершить',
          icon: EvIcons.power,
          height: m.buttonHeight,
          danger: true,
          grouped: true,
          onPressed: widget.onQuit,
        ),
      ];
    }
    return [
      if (content.action == null)
        EvPlayButton(
          height: m.buttonHeight,
          requireHold: effects?.holdToPlay ?? true,
          onLaunch: widget.onLaunch ?? () {},
          onCharge: (value) => _charge.value = value,
        )
      else
        EvPlayButton(
          label: content.action!,
          icon: EvIcons.download,
          caption: content.actionCaption,
          height: m.buttonHeight,
          requireHold: false,
          onLaunch: widget.onInstall,
        ),
      EvGhostButton(
        label: content.second ?? 'Подробнее',
        icon: content.secondIcon ?? EvIcons.info,
        height: m.buttonHeight,
        grouped: true,
        // «Играть без обновления» запускает ту же игру; «Указать папку» —
        // дело движка, которого ещё нет.
        onPressed: content.second == null
            ? widget.onDetails
            : (content.secondIcon == EvIcons.play ? widget.onLaunch : null),
      ),
    ];
  }

  Widget _body(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final m = widget.layout;
    final effects = EvEffectsScope.maybeOf(context);
    final words = widget.title.trim().split(' ');
    final light = words.sublist(0, words.length - 1).join(' ');

    final titleStyle = ev.text
        .display(m.titleSize)
        .copyWith(
          leadingDistribution: TextLeadingDistribution.even,
          shadows: [
            const Shadow(color: Color(0xCC000000), blurRadius: 44),
            Shadow(color: c.hot1.withValues(alpha: .16), blurRadius: 90),
          ],
        );
    final blurbStyle = ev.text.body.copyWith(fontSize: m.blurbSize);
    final content = widget.content;
    // На низком окне высокая полоса действий и строка под ней забирают
    // место у описания — в прототипе оно там же и прячется.
    final tall = content.install != null || content.action != null;
    final below = content.note != null || content.savePoint != null;
    final showBlurb = !(m.low && (tall || below));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        EvEyebrow(content.eyebrow),
        SizedBox(height: m.bodyGap),
        // две строки на экране, одно название для экранного диктора
        Semantics(
          header: true,
          label: widget.title,
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (light.isNotEmpty) Text(light, style: titleStyle),
              Text(
                words.last,
                style: ev.text.dsp(titleStyle, weight: FontWeight.w800),
              ),
            ],
          ),
        ),
        if (showBlurb) ...[
          SizedBox(height: m.bodyGap),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: m.blurbChars * evCharWidth(blurbStyle),
            ),
            child: Text(content.blurb, style: blurbStyle),
          ),
        ],
        SizedBox(height: m.bodyGap),
        // Чипы и «Подробнее» — линзы поверх одного и того же кадра:
        // фон они читают один раз на всех.
        BackdropGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (label, hot) in content.chips)
                    EvChip(label, hot: hot, grouped: true),
                ],
              ),
              SizedBox(height: m.bodyGap + m.ctaTop),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: _cta(context, effects),
              ),
              if (content.note != null) ...[
                SizedBox(height: m.bodyGap),
                EvCtaNote(content.note!),
              ],
              // Точка сохранения живёт под кнопкой: второй запуск
              // начинается не с игры, а с места, где её закрыли.
              if (content.savePoint != null) ...[
                SizedBox(height: m.bodyGap),
                EvSavePointCard(
                  spot: content.savePoint!,
                  onOther: widget.onOtherSave,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Сдвиг за курсором на глубину [depth]: по вертикали вдвое с лишним меньше,
/// как `translate3d(-ox·d, -oy·d·.55)` в прототипе. Отрицательная глубина
/// идёт вместе с курсором.
class _Depth extends StatelessWidget {
  const _Depth({
    required this.pointer,
    required this.depth,
    required this.child,
  });

  final ValueListenable<Offset>? pointer;
  final double depth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pointer = this.pointer;
    if (pointer == null) return child;
    return ValueListenableBuilder<Offset>(
      valueListenable: pointer,
      child: child,
      builder: (context, p, child) =>
          Transform.translate(offset: evParallaxOffset(p, depth), child: child),
    );
  }
}

/// Сдвиг слоя глубины [depth] при курсоре [pointer] в долях окна.
Offset evParallaxOffset(Offset pointer, double depth) =>
    Offset(-(pointer.dx - .5) * depth, -(pointer.dy - .5) * depth * .55);

/// Ключевой кадр героя: три слоя из растрового кэша, каждый со своим
/// запасом и глубиной. Кадры параллакса только перекладывают текстуры.
@visibleForTesting
class EvHeroArtPainter extends CustomPainter {
  EvHeroArtPainter({
    required this.palette,
    required this.seed,
    required this.devicePixelRatio,
    required this.pointer,
    required this.charge,
    required this.clock,
  }) : super(repaint: Listenable.merge([pointer, charge]));

  final EvCoverPalette palette;
  final int seed;
  final double devicePixelRatio;

  /// Курсор; `null` — параллакс выключен, слои по центру.
  final ValueListenable<Offset>? pointer;

  /// Заряд «Играть»; `null` — марево выключено.
  final ValueListenable<double>? charge;

  /// Время марева.
  final Stopwatch clock;

  /// Наибольший сдвиг марева, px. У `feDisplacementMap` с `scale="9"`
  /// предел — 4,5 px в обе стороны, но шум `fractalNoise` редко отходит от
  /// середины дальше чем на четверть, и на деле кадр плывёт на 2–2,5 px.
  static const hazeAmplitude = 2.5;

  /// Высота полосы марева, px. Полосы в пиксель не рвут силуэты: соседние
  /// сдвигаются на доли пикселя.
  static const _band = 1.0;

  /// Где лежит слой [layer] в герое размером [size]: запас с каждой
  /// стороны, сдвиг параллакса и кадр 16 : 9, вписанный по «cover».
  static Rect layerRect(EvHeroLayer layer, Size size, Offset? pointer) {
    final box =
        Rect.fromLTRB(
          -size.width * layer.bleed,
          -size.height * layer.bleed,
          size.width * (1 + layer.bleed),
          size.height * (1 + layer.bleed),
        ).shift(
          pointer == null
              ? Offset.zero
              : evParallaxOffset(pointer, layer.depth),
        );
    final fit = math.max(
      box.width / EvHeroLayer.scene.width,
      box.height / EvHeroLayer.scene.height,
    );
    return Rect.fromCenter(
      center: box.center,
      width: EvHeroLayer.scene.width * fit,
      height: EvHeroLayer.scene.height * fit,
    );
  }

  /// Масштаб растра: пикселей текстуры на пиксель сцены, ступенями
  /// по четверти, чтобы перетаскивание края окна не перерисовывало кадр
  /// на каждом шаге. Не больше 2,5 — на 4K слой и так крупнее экрана.
  static double rasterScale(double pixelsPerScenePixel) =>
      (pixelsPerScenePixel * 4).ceil().clamp(2, 10) / 4;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final p = pointer?.value;
    final heat = math.min(1.0, (charge?.value ?? 0) / .2);
    final paint = Paint()..filterQuality = FilterQuality.low;
    for (final layer in EvHeroLayer.values) {
      final dst = layerRect(layer, size, p);
      final image = EvArtCache.heroLayer(
        layer,
        palette,
        seed,
        rasterScale(dst.width / EvHeroLayer.scene.width * devicePixelRatio),
      );
      if (heat <= 0) {
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          dst,
          paint,
        );
      } else {
        _paintHaze(canvas, size, image, dst, heat, paint);
      }
    }
  }

  /// Марево: слой режется на полосы в пиксель, и каждая сдвигается вбок
  /// гладкой волной — те же 33 px периода по вертикали, что у шума
  /// `baseFrequency="0.012 0.03"` в прототипе, и вдвое мельче второй
  /// октавой. Одна текстура, один вызов `drawAtlas`.
  void _paintHaze(
    Canvas canvas,
    Size size,
    ui.Image image,
    Rect dst,
    double heat,
    Paint paint,
  ) {
    final t = clock.elapsedMicroseconds / 1e6;
    final scale = dst.width / image.width;
    final transforms = <RSTransform>[];
    final rects = <Rect>[];
    for (
      var y = math.max(0.0, dst.top);
      y < math.min(size.height, dst.bottom);
      y += _band
    ) {
      final wave =
          .62 * math.sin(y / 33 * 2 * math.pi + t * 1.9) +
          .38 * math.sin(y / 17 * 2 * math.pi - t * 2.7 + 1.3);
      transforms.add(
        RSTransform.fromComponents(
          rotation: 0,
          scale: scale,
          anchorX: 0,
          anchorY: 0,
          translateX: dst.left + wave * hazeAmplitude * heat,
          translateY: y,
        ),
      );
      rects.add(
        Rect.fromLTWH(
          0,
          (y - dst.top) / scale,
          image.width.toDouble(),
          _band / scale,
        ),
      );
    }
    canvas.drawAtlas(image, transforms, rects, null, null, null, paint);
  }

  @override
  bool shouldRepaint(EvHeroArtPainter old) =>
      old.palette != palette ||
      old.seed != seed ||
      old.devicePixelRatio != devicePixelRatio ||
      old.pointer != pointer ||
      old.charge != charge;
}

/// Кинематографическая подложка под текстом — `.hero::after`: слева и снизу
/// кадр уходит в цвет подложки, по краям темнеет эллипсом.
class _GradePainter extends CustomPainter {
  _GradePainter(this.sub);

  final Color sub;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final full = Offset.zero & size;
    // В CSS градиенты смешиваются с предумноженной альфой: «transparent»
    // не уводит цвет в чёрный. Здесь прозрачные точки — того же цвета.
    const vignette = Color.fromRGBO(3, 3, 6, 1);
    final center = Offset(w * .78, h * .30);
    final rx = w * 1.2, ry = h * .9;
    canvas
      ..drawRect(
        full,
        Paint()
          ..shader = ui.Gradient.radial(
            center,
            rx,
            [vignette.withValues(alpha: 0), vignette.withValues(alpha: .62)],
            const [.4, 1],
            TileMode.clamp,
            (Matrix4.translationValues(center.dx, center.dy, 0)
                  ..multiply(Matrix4.diagonal3Values(1, ry / rx, 1))
                  ..multiply(
                    Matrix4.translationValues(-center.dx, -center.dy, 0),
                  ))
                .storage,
          ),
      )
      ..drawRect(
        full,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, h),
            Offset.zero,
            [sub, sub.withValues(alpha: 0)],
            const [.01, .44],
          ),
      )
      ..drawRect(
        full,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(w, 0),
            [
              sub,
              sub.withValues(alpha: .86),
              sub.withValues(alpha: .12),
              sub.withValues(alpha: 0),
            ],
            const [.02, .30, .66, 1],
          ),
      );
  }

  @override
  bool shouldRepaint(_GradePainter old) => old.sub != sub;
}
