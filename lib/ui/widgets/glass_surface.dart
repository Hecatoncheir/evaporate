import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Унифицированная аппаратная поверхность: матовая заливка, тонкий световой
/// кант и небольшая глубина, как у панели из окрашенного алюминия.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    required this.radius,
    this.padding,
    this.opacity,
    this.shadow = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final double? opacity;
  final bool shadow;

  /// Кант по всем краям — у отдельной панели. Полосам каркаса у края
  /// панели он нужен только на стыке с разделами.
  static const allSides = {
    AxisDirection.up,
    AxisDirection.right,
    AxisDirection.down,
    AxisDirection.left,
  };

  /// Что стекло делает с подложкой: размывает её, а размытое — ночью —
  /// делает насыщеннее и темнее: стекло собирает свет, и под ним он гуще,
  /// чем рядом. Днём стекло почти только размывает: на светлом корпусе
  /// густой цвет под панелью читался бы грязью. Матрица — как `saturate()`
  /// и `brightness()` в CSS, светимость по Rec. 709.
  ///
  /// Отдельно от виджета, потому что стекло бывает и сливером: фильтр у
  /// двух карточек рядом обязан быть один.
  static ImageFilter filterOf(GlassSurfaceTheme glass) => ImageFilter.compose(
    outer: _tintOf(glass),
    inner: ImageFilter.blur(
      sigmaX: glass.backdropBlur,
      sigmaY: glass.backdropBlur,
    ),
  );

  /// Тот же фильтр для стёкол, читающих общий снимок фона
  /// (`BackdropFilter.grouped`), — с размытием, которое берёт подложку
  /// только из-под самой панели: снимок один на весь экран, и обычное
  /// размытие тянуло бы на край панели цвет соседа. [blurScale] — качество
  /// украшений.
  static ImageFilterConfig groupedFilterOf(
    GlassSurfaceTheme glass, {
    double blurScale = 1,
  }) => ImageFilterConfig.compose(
    outer: ImageFilterConfig(_tintOf(glass)),
    inner: ImageFilterConfig.blur(
      sigmaX: glass.backdropBlur * blurScale,
      sigmaY: glass.backdropBlur * blurScale,
      bounded: true,
    ),
  );

  static ColorFilter _tintOf(GlassSurfaceTheme glass) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final s = glass.backdropSaturation;
    final b = glass.backdropBrightness;
    return ColorFilter.matrix([
      (lr + (1 - lr) * s) * b, (lg - lg * s) * b, (lb - lb * s) * b, 0, 0, //
      (lr - lr * s) * b, (lg + (1 - lg) * s) * b, (lb - lb * s) * b, 0, 0, //
      (lr - lr * s) * b, (lg - lg * s) * b, (lb + (1 - lb) * s) * b, 0, 0, //
      0, 0, 0, 1, 0,
    ]);
  }

  /// Заливка, отлив, кант и тени стекла — без размытия и обрезки.
  ///
  /// Отдельно от виджета, потому что стекло бывает и сливером
  /// (`GlassSliver`): ленивый список в коробку не обернуть, а облик у двух
  /// карточек рядом обязан быть один. И плотной панелью,
  /// которая знает флаг «Стекло»: [opaque] — панель, не читающая подложку,
  /// с плотной заливкой без просвета к углу.
  static BoxDecoration decorationOf(
    BuildContext context, {
    required double radius,
    double? opacity,
    bool shadow = true,
    bool opaque = false,
    Set<AxisDirection> rim = allSides,
  }) {
    final colors = context.colors;
    final surface = HardwareSurfaceTheme.of(context);
    final glass = GlassSurfaceTheme.of(context);
    final fill = opaque
        ? glass.opaqueFillOpacity
        : opacity ?? glass.fillOpacity;
    // Отлив плотной панели не прозрачнее заливки: ночного отлива нет, и при
    // смене схемы он смешивается как заливка 0.62 — край плотной полосы на
    // кадр просвечивал бы.
    final sheen = glass.sheenTopOpacity ?? fill;
    final top = opaque ? math.max(fill, sheen) : sheen;
    return BoxDecoration(
      color: colors.surface.withValues(alpha: fill),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colors.surface.withValues(alpha: top),
          colors.surfaceHigh.withValues(
            alpha: opaque ? fill : glass.sheenBottomOpacity,
          ),
        ],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: _rimOf(colors, glass, rim),
      boxShadow: shadow
          ? [
              BoxShadow(
                color: surface.shadow,
                blurRadius: 24,
                offset: const Offset(10, 14),
              ),
              BoxShadow(
                color: colors.textPrimary.withValues(
                  alpha: glass.counterLightOpacity,
                ),
                blurRadius: 12,
                offset: const Offset(-5, -5),
              ),
            ]
          : null,
    );
  }

  /// Светлый кант по названным краям.
  static Border _rimOf(
    EvaporatePalette colors,
    GlassSurfaceTheme glass,
    Set<AxisDirection> rim,
  ) {
    final edge = BorderSide(
      color: colors.textPrimary.withValues(alpha: glass.rimOpacity),
    );
    BorderSide side(AxisDirection at) =>
        rim.contains(at) ? edge : BorderSide.none;
    return Border(
      top: side(AxisDirection.up),
      right: side(AxisDirection.right),
      bottom: side(AxisDirection.down),
      left: side(AxisDirection.left),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: filterOf(GlassSurfaceTheme.of(context)),
        child: DecoratedBox(
          decoration: decorationOf(
            context,
            radius: radius,
            opacity: opacity,
            shadow: shadow,
          ),
          child: Material(
            color: AppColors.transparent,
            child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
          ),
        ),
      ),
    );
  }
}
