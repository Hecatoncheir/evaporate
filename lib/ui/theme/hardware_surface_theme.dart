import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Материал корпуса: плотность панелей, тени, свет и затемнения.
///
/// Две схемы расходятся здесь **данными**, а не ветвлениями в виджетах:
/// прежде облик решали три десятка `isDark ? … : …` по двенадцати файлам,
/// и третья схема потребовала бы правки каждого. Экземпляров ровно два —
/// ночной «Арклайт» и дневной «Картридж», — а не наследники: тема — это
/// данные, и плавная смена схемы смешивает их по полям (`lerp`).
///
/// Лежит в папке темы, а не рядом с виджетами: цвета в приложении
/// заводятся только здесь, и за этим следит `color_palette_test`.
@immutable
class HardwareSurfaceTheme extends ThemeExtension<HardwareSurfaceTheme> {
  const HardwareSurfaceTheme({
    required this.fillOpacity,
    required this.sheenTopOpacity,
    required this.sheenBottomOpacity,
    required this.rimOpacity,
    required this.shadow,
    required this.counterLightOpacity,
    required this.backdropCoolOpacity,
    required this.backdropDeepOpacity,
    required this.backdropWarmOpacity,
    required this.grilleHole,
    required this.shellOpacity,
    required this.toolbarOpacity,
    required this.cardOpacity,
    required this.readoutOpacity,
    required this.scrimOpacity,
    required this.ambientStrength,
    required this.vignetteOpacity,
    required this.keySheen,
    required this.railShadowBlur,
    required this.railShadowDrop,
    required this.frameShadowBlur,
    required this.frameShadowDrop,
  });

  /// Непрозрачность стеклянной панели по умолчанию.
  final double fillOpacity;

  /// Отлив сверху слева; `null` — как заливка. Днём корпус светлее у кромки.
  final double? sheenTopOpacity;

  /// Отлив снизу справа — ближе к подложке.
  final double sheenBottomOpacity;

  /// Светлый кант по краю панели.
  final double rimOpacity;

  /// Тень под стеклянной панелью.
  final Color shadow;

  /// Встречный блик с верхнего левого угла.
  final double counterLightOpacity;

  /// Холодный, глубокий и тёплый свет подложки окна.
  final double backdropCoolOpacity;
  final double backdropDeepOpacity;
  final double backdropWarmOpacity;

  /// Отверстия декоративной решётки.
  final Color grilleHole;

  /// Панель оболочки поверх света игр — нарочно неплотная: заливка в упор
  /// погасила бы единственный цвет в окне.
  final double shellOpacity;

  /// Подложка панели инструментов библиотеки.
  final double toolbarOpacity;

  /// Карточка раздела.
  final double cardOpacity;

  /// Панель показаний.
  final double readoutOpacity;

  /// Затемнение обложки под страницей игры: белый текст на светлой обложке
  /// обязан остаться виден.
  final double scrimOpacity;

  /// Сила цветного света игр. Светлый корпус берёт его вполсилы: на белом
  /// насыщенный свет читается как грязь на панели, а не как подсветка.
  final double ambientStrength;

  /// Затемнение краёв окна под светом игр.
  final double vignetteOpacity;

  /// Доля отлива на главной клавише.
  final double keySheen;

  /// Тень рейки навигации: размытие и сдвиг вниз.
  final double railShadowBlur;
  final double railShadowDrop;

  /// Тень крупного кадра библиотеки.
  final double frameShadowBlur;
  final double frameShadowDrop;

  static const arclight = HardwareSurfaceTheme(
    fillOpacity: 0.9,
    sheenTopOpacity: null,
    sheenBottomOpacity: 0.62,
    rimOpacity: 0.15,
    shadow: Color(0x8C000000),
    counterLightOpacity: 0.05,
    backdropCoolOpacity: 0.14,
    backdropDeepOpacity: 0.36,
    backdropWarmOpacity: 0.16,
    grilleHole: Color(0xB8000000),
    shellOpacity: 0.62,
    toolbarOpacity: 0.72,
    cardOpacity: 0.62,
    readoutOpacity: 0.7,
    scrimOpacity: 0.72,
    ambientStrength: 1,
    vignetteOpacity: 0.62,
    keySheen: 0.16,
    railShadowBlur: 22,
    railShadowDrop: 10,
    frameShadowBlur: 34,
    frameShadowDrop: 14,
  );

  static const cartridge = HardwareSurfaceTheme(
    fillOpacity: 0.94,
    sheenTopOpacity: 0.98,
    sheenBottomOpacity: 0.72,
    rimOpacity: 0.32,
    shadow: Color(0x578A8574),
    counterLightOpacity: 0.16,
    backdropCoolOpacity: 0.32,
    backdropDeepOpacity: 0.12,
    backdropWarmOpacity: 0.12,
    grilleHole: Color(0xC2333738),
    shellOpacity: 0.78,
    toolbarOpacity: 0.84,
    cardOpacity: 0.74,
    readoutOpacity: 0.6,
    scrimOpacity: 0.82,
    ambientStrength: 0.4,
    vignetteOpacity: 0.14,
    keySheen: 0.04,
    railShadowBlur: 8,
    railShadowDrop: 2,
    frameShadowBlur: 12,
    frameShadowDrop: 3,
  );

  static HardwareSurfaceTheme of(BuildContext context) =>
      Theme.of(context).extension<HardwareSurfaceTheme>() ?? arclight;

  /// Все поля по порядку — для сравнения и для проверки, что `lerp` и
  /// `copyWith` не забыли ни одного.
  List<Object?> get values => [
    fillOpacity,
    sheenTopOpacity,
    sheenBottomOpacity,
    rimOpacity,
    shadow,
    counterLightOpacity,
    backdropCoolOpacity,
    backdropDeepOpacity,
    backdropWarmOpacity,
    grilleHole,
    shellOpacity,
    toolbarOpacity,
    cardOpacity,
    readoutOpacity,
    scrimOpacity,
    ambientStrength,
    vignetteOpacity,
    keySheen,
    railShadowBlur,
    railShadowDrop,
    frameShadowBlur,
    frameShadowDrop,
  ];

  @override
  HardwareSurfaceTheme copyWith({double? fillOpacity, double? shellOpacity}) =>
      HardwareSurfaceTheme(
        fillOpacity: fillOpacity ?? this.fillOpacity,
        sheenTopOpacity: sheenTopOpacity,
        sheenBottomOpacity: sheenBottomOpacity,
        rimOpacity: rimOpacity,
        shadow: shadow,
        counterLightOpacity: counterLightOpacity,
        backdropCoolOpacity: backdropCoolOpacity,
        backdropDeepOpacity: backdropDeepOpacity,
        backdropWarmOpacity: backdropWarmOpacity,
        grilleHole: grilleHole,
        shellOpacity: shellOpacity ?? this.shellOpacity,
        toolbarOpacity: toolbarOpacity,
        cardOpacity: cardOpacity,
        readoutOpacity: readoutOpacity,
        scrimOpacity: scrimOpacity,
        ambientStrength: ambientStrength,
        vignetteOpacity: vignetteOpacity,
        keySheen: keySheen,
        railShadowBlur: railShadowBlur,
        railShadowDrop: railShadowDrop,
        frameShadowBlur: frameShadowBlur,
        frameShadowDrop: frameShadowDrop,
      );

  @override
  HardwareSurfaceTheme lerp(
    ThemeExtension<HardwareSurfaceTheme>? other,
    double t,
  ) {
    if (other is! HardwareSurfaceTheme) return this;
    double mix(double a, double b) => lerpDouble(a, b, t)!;
    return HardwareSurfaceTheme(
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
      shadow: Color.lerp(shadow, other.shadow, t)!,
      counterLightOpacity: mix(counterLightOpacity, other.counterLightOpacity),
      backdropCoolOpacity: mix(backdropCoolOpacity, other.backdropCoolOpacity),
      backdropDeepOpacity: mix(backdropDeepOpacity, other.backdropDeepOpacity),
      backdropWarmOpacity: mix(backdropWarmOpacity, other.backdropWarmOpacity),
      grilleHole: Color.lerp(grilleHole, other.grilleHole, t)!,
      shellOpacity: mix(shellOpacity, other.shellOpacity),
      toolbarOpacity: mix(toolbarOpacity, other.toolbarOpacity),
      cardOpacity: mix(cardOpacity, other.cardOpacity),
      readoutOpacity: mix(readoutOpacity, other.readoutOpacity),
      scrimOpacity: mix(scrimOpacity, other.scrimOpacity),
      ambientStrength: mix(ambientStrength, other.ambientStrength),
      vignetteOpacity: mix(vignetteOpacity, other.vignetteOpacity),
      keySheen: mix(keySheen, other.keySheen),
      railShadowBlur: mix(railShadowBlur, other.railShadowBlur),
      railShadowDrop: mix(railShadowDrop, other.railShadowDrop),
      frameShadowBlur: mix(frameShadowBlur, other.frameShadowBlur),
      frameShadowDrop: mix(frameShadowDrop, other.frameShadowDrop),
    );
  }
}
