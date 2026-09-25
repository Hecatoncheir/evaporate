import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../atmosphere/ev_atmosphere.dart';
import '../atmosphere/film_grain.dart';
import '../design/effects.dart';
import '../design/theme.dart';
import 'glass_lens.dart';
import 'glass_style.dart';
import 'glass_surface.dart';

export 'glass_style.dart';

/// Стекло Evaporate.
///
/// Пар поднимается за интерфейсом, а интерфейс — то, на чём он оседает:
/// навигационный слой сделан из стекла, и сквозь него видно, что
/// происходит позади. Отсюда два материала ([EvGlassStyle.frost] и
/// [EvGlassStyle.lens]) и одно правило: стекло лежит поверх содержимого,
/// а не вместо него.
///
/// Стекло состоит из четырёх вещей, и ни одна не лишняя:
/// * **фон** — размытый, чуть темнее и насыщеннее, чем рядом;
/// * **преломление** у кромки — только под Impeller, см. [EvGlassLens];
/// * **заливка** — ступень поверхности из палитры облика;
/// * **свет** — блик на кромке и свечение внутри, оба ходят за курсором.
///
/// Выключается в «Настройках → Эффекты»: без стекла остаётся заливка
/// поплотнее и та же кромка.
class EvGlass extends StatefulWidget {
  const EvGlass({
    super.key,
    required this.child,
    this.style = EvGlassStyle.frost,
    this.borderRadius,
    this.tint,
    this.keyLight,
    this.padding,
    this.shadows = const [],
    this.interactive = false,
    this.pressed = false,
    this.grouped = false,
    this.backdrop = true,
    this.rim,
  });

  final Widget child;
  final EvGlassStyle style;

  /// Скругление; по умолчанию — потолок панелей.
  final BorderRadius? borderRadius;

  /// Заливка вместо той, что задаёт материал: ею красят горячий чип
  /// и вообще всё, что должно отличаться цветом, а не формой.
  final Color? tint;

  /// Цвет света на кромке. По умолчанию белый, подогретый акцентом
  /// облика: тема задаёт температуру источника света. Задают его там,
  /// где у предмета свой цвет, — горячий чип, красная плашка.
  final Color? keyLight;

  final EdgeInsetsGeometry? padding;
  final List<BoxShadow> shadows;

  /// Стекло откликается на курсор: загорается под ним и прижимается
  /// при нажатии.
  final bool interactive;

  /// Кнопку держат нажатой.
  final bool pressed;

  /// Читать общий снимок фона ближайшей [BackdropGroup] вместо своего.
  ///
  /// Так делают только стёкла одного слоя, которые не перекрывают друг
  /// друга: полосы каркаса, чипы в герое. Снимок берётся на первом из
  /// них, поэтому всё, что нарисовано между ними, в фон соседа не попадёт.
  final bool grouped;

  /// Читать фон вообще. Мелочь поверх другого стекла (клавиши, капли
  /// выбора) читает его впустую: под ней уже всё размыто.
  final bool backdrop;

  /// Стороны, на которых светится кромка; `null` — весь периметр.
  /// Полосы каркаса стыкуются с соседями: кромка у них только на стыке,
  /// а стороны у края окна её не видят.
  final Set<AxisDirection>? rim;

  @override
  State<EvGlass> createState() => _EvGlassState();
}

class _EvGlassState extends State<EvGlass> with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    reverseDuration: const Duration(milliseconds: 240),
  );

  Offset? _hover;

  @override
  void initState() {
    super.initState();
    if (widget.style.grain) EvFilmGrain.load();
    if (_wantsLens) _listenLens();
  }

  @override
  void didUpdateWidget(EvGlass old) {
    super.didUpdateWidget(old);
    if (widget.pressed != old.pressed) {
      widget.pressed ? _press.forward() : _press.reverse();
    }
    if (widget.style.grain && !old.style.grain) EvFilmGrain.load();
    if (_wantsLens) _listenLens();
  }

  @override
  void dispose() {
    EvGlassLens.ready.removeListener(_onLensReady);
    _press.dispose();
    super.dispose();
  }

  bool get _wantsLens =>
      widget.backdrop && widget.style.bevel > 0 && EvGlassLens.supported;

  void _listenLens() {
    EvGlassLens.ready.removeListener(_onLensReady);
    if (EvGlassLens.ready.value) return;
    EvGlassLens.ready.addListener(_onLensReady);
    EvGlassLens.load();
  }

  void _onLensReady() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final effects = EvEffectsScope.maybeOf(context);
    final quality = effects?.quality ?? EvEffectsQuality.full;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final style = widget.style;
    final radius = widget.borderRadius ?? BorderRadius.circular(ev.radii.r4);

    final blur = style.blur * quality.blurScale;
    final glass = widget.backdrop && (effects?.glass ?? true) && blur > 0;
    final lens =
        glass &&
        style.bevel > 0 &&
        (effects?.refraction ?? true) &&
        quality.lens &&
        EvGlassLens.ready.value;

    // Без размытия стекло держится только заливкой, поэтому она плотнее:
    // прозрачная плашка поверх резкого фона — не стекло, а грязь.
    final fill = widget.tint ?? style.fill(ev.colors);
    final opaque = glass
        ? fill
        : fill.withValues(alpha: (fill.a * 1.7).clamp(0.0, 0.96));

    return AnimatedBuilder(
      animation: _press,
      builder: (context, child) {
        final press = reduced ? 0.0 : Curves.easeOut.transform(_press.value);
        Widget content = EvGlassSurface(
          style: style,
          fill: opaque,
          radius: radius,
          keyLight:
              widget.keyLight ??
              Color.lerp(const Color(0xFFFFFFFF), ev.colors.hot2, 0.28)!,
          pointer: reduced ? null : EvAtmosphere.pointerOf(context),
          window: MediaQuery.sizeOf(context),
          hover: _hover,
          press: press,
          rim: widget.rim,
          child: widget.padding == null
              ? child!
              : Padding(padding: widget.padding!, child: child),
        );

        final color = evGlassColorFilter(style.saturation, style.brightness);
        if (lens) {
          content = EvGlassLensBackdrop(
            radius: radius,
            blur: blur,
            color: color,
            bevel: style.bevel,
            // Нажатие делает стекло толще: кромка гнёт фон сильнее.
            depth: style.depth * (1 + press * 0.45),
            dispersion: style.dispersion * quality.dispersionScale,
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            backdropKey: widget.grouped
                ? BackdropGroup.of(context)?.backdropKey
                : null,
            child: content,
          );
        } else if (glass) {
          var config = ImageFilterConfig.blur(
            sigmaX: blur,
            sigmaY: blur,
            bounded: true,
          );
          if (color != null) {
            config = ImageFilterConfig.compose(
              outer: ImageFilterConfig(color),
              inner: config,
            );
          }
          content = ClipRRect(
            borderRadius: radius,
            child: widget.grouped
                ? BackdropFilter.grouped(filterConfig: config, child: content)
                : BackdropFilter(filterConfig: config, child: content),
          );
        } else {
          content = ClipRRect(borderRadius: radius, child: content);
        }

        if (widget.shadows.isNotEmpty) {
          content = DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: widget.shadows,
            ),
            child: content,
          );
        }
        if (press > 0) {
          content = Transform.scale(scale: 1 + 0.035 * press, child: content);
        }
        if (!widget.interactive) return content;
        return MouseRegion(
          opaque: false,
          onHover: (event) => setState(() => _hover = event.localPosition),
          onExit: (_) => setState(() => _hover = null),
          child: content,
        );
      },
      child: widget.child,
    );
  }
}

/// Цвет фона под стеклом: стекло собирает свет, поэтому под ним
/// насыщеннее и темнее, чем рядом. Матрица — как `saturate()`
/// и `brightness()` в CSS, светимость по Rec. 709.
ui.ColorFilter? evGlassColorFilter(double saturation, double brightness) {
  if (saturation == 1 && brightness == 1) return null;
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final s = saturation, b = brightness;
  return ui.ColorFilter.matrix(<double>[
    (lr + (1 - lr) * s) * b, (lg - lg * s) * b, (lb - lb * s) * b, 0, 0, //
    (lr - lr * s) * b, (lg + (1 - lg) * s) * b, (lb - lb * s) * b, 0, 0, //
    (lr - lr * s) * b, (lg - lg * s) * b, (lb + (1 - lb) * s) * b, 0, 0, //
    0, 0, 0, 1, 0,
  ]);
}
