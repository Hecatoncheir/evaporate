import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Облик стеклянной панели (`GlassSurface`): плотность, отливы, кант и
/// встречный блик.
///
/// Своим расширением, а не полями `HardwareSurfaceTheme`: тот стал мешком
/// ручек одиннадцати виджетов, и шесть его полей из двадцати двух читала
/// одна эта панель. Тема компонента лежит одна на компонент, два экземпляра
/// на две схемы, — как `EffectsPalette` у украшений.
@immutable
class GlassSurfaceTheme extends ThemeExtension<GlassSurfaceTheme> {
  const GlassSurfaceTheme({
    required this.fillOpacity,
    required this.sheenTopOpacity,
    required this.sheenBottomOpacity,
    required this.rimOpacity,
    required this.counterLightOpacity,
  });

  /// Непрозрачность панели по умолчанию.
  final double fillOpacity;

  /// Отлив сверху слева; `null` — как заливка. Днём корпус светлее у кромки.
  final double? sheenTopOpacity;

  /// Отлив снизу справа — ближе к подложке.
  final double sheenBottomOpacity;

  /// Светлый кант по краю панели.
  final double rimOpacity;

  /// Встречный блик с верхнего левого угла.
  final double counterLightOpacity;

  static const arclight = GlassSurfaceTheme(
    fillOpacity: 0.9,
    sheenTopOpacity: null,
    sheenBottomOpacity: 0.62,
    rimOpacity: 0.15,
    counterLightOpacity: 0.05,
  );

  static const cartridge = GlassSurfaceTheme(
    fillOpacity: 0.94,
    sheenTopOpacity: 0.98,
    sheenBottomOpacity: 0.72,
    rimOpacity: 0.32,
    counterLightOpacity: 0.16,
  );

  static GlassSurfaceTheme of(BuildContext context) =>
      Theme.of(context).extension<GlassSurfaceTheme>() ?? arclight;

  /// Все поля по порядку — для проверки, что `lerp` не забыл ни одного.
  List<Object?> get values => [
    fillOpacity,
    sheenTopOpacity,
    sheenBottomOpacity,
    rimOpacity,
    counterLightOpacity,
  ];

  @override
  GlassSurfaceTheme copyWith({double? fillOpacity}) => GlassSurfaceTheme(
    fillOpacity: fillOpacity ?? this.fillOpacity,
    sheenTopOpacity: sheenTopOpacity,
    sheenBottomOpacity: sheenBottomOpacity,
    rimOpacity: rimOpacity,
    counterLightOpacity: counterLightOpacity,
  );

  @override
  GlassSurfaceTheme lerp(ThemeExtension<GlassSurfaceTheme>? other, double t) {
    if (other is! GlassSurfaceTheme) return this;
    double mix(double a, double b) => lerpDouble(a, b, t)!;
    return GlassSurfaceTheme(
      fillOpacity: mix(fillOpacity, other.fillOpacity),
      // Концы смешиваются как есть: на `t = 0` и `t = 1` получается ровно
      // своя схема, в том числе «как заливка» у ночной.
      sheenTopOpacity: t == 0
          ? sheenTopOpacity
          : t == 1
          ? other.sheenTopOpacity
          : mix(
              sheenTopOpacity ?? fillOpacity,
              other.sheenTopOpacity ?? other.fillOpacity,
            ),
      sheenBottomOpacity: mix(sheenBottomOpacity, other.sheenBottomOpacity),
      rimOpacity: mix(rimOpacity, other.rimOpacity),
      counterLightOpacity: mix(counterLightOpacity, other.counterLightOpacity),
    );
  }
}
