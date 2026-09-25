import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../models/library_effect.dart';
import '../theme.dart';
import '../widgets/glass_surface.dart';

/// Стекло полос каркаса: обоймы, рейки и строки подсказок.
///
/// Единственное место, которое знает флаг «Стекло» и качество украшений:
/// `GlassSurface` блока не читает и годится где угодно, а решать за него
/// про настройки значило бы тянуть блок в каждую карточку.
///
/// Полосы читают **один общий снимок** фона — `BackdropGroup` в
/// `ShellLayout`. Снимок берётся на первой из них, поэтому всё, что лежит
/// под любой полосой, обязано быть нарисовано раньше первой: полосы не
/// перекрываются и идут в раскладке последними, а обойма — после панели.
///
/// Без стекла фильтр остаётся на месте выключенным, а не уходит из
/// дерева: иначе смена настройки пересобирала бы полосы с их клавишами и
/// подсказками заново.
class ShellGlass extends StatelessWidget {
  const ShellGlass({
    super.key,
    required this.child,
    this.radius,
    this.rim = GlassSurface.allSides,
    this.shadows = const [],
  });

  final Widget child;

  /// Нет — углы прямые: полосу у края панели обрезает сама панель.
  final double? radius;

  /// По каким краям идёт кант. Полосе у края панели он нужен только на
  /// стыке с разделами: остальные её края — края самой панели.
  final Set<AxisDirection> rim;

  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) {
    final (glass, blurScale) = context.select<SettingsBloc, (bool, double)>(
      (bloc) => (
        bloc.state.appearance.shows(LibraryEffect.glass),
        bloc.state.appearance.effectQuality.blurScale,
      ),
    );
    final corner = radius ?? 0;
    final borderRadius = BorderRadius.circular(corner);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: shadows),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter.grouped(
          enabled: glass,
          filterConfig: GlassSurface.groupedFilterOf(
            GlassSurfaceTheme.of(context),
            blurScale: blurScale,
          ),
          child: DecoratedBox(
            decoration: GlassSurface.decorationOf(
              context,
              radius: corner,
              shadow: false,
              opaque: !glass,
              rim: rim,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
