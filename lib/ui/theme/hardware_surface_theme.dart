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
///
/// Ручки здесь одиночные — по одной на панель, полосу, карточку, — и это
/// не мешок, а материал: все они про то, насколько плотен корпус и сколько
/// света он пропускает, и крутят их вместе, меняя облик схемы. Своё
/// расширение получает компонент с тремя ручками и больше, как стекло
/// (`GlassSurfaceTheme`); класс темы на одно поле — церемония без выгоды
/// (`docs/decisions/0002-theme-in-three-tiers.md`).
@immutable
class HardwareSurfaceTheme extends ThemeExtension<HardwareSurfaceTheme> {
  const HardwareSurfaceTheme({
    required this.shadow,
    required this.shellOpacity,
    required this.toolbarOpacity,
    required this.cardOpacity,
    required this.materialCardOpacity,
    required this.readoutOpacity,
    required this.scrimOpacity,
    required this.ambientStrength,
    required this.vignetteOpacity,
    required this.railShadowBlur,
    required this.railShadowDrop,
    required this.frameShadowBlur,
    required this.frameShadowDrop,
  });

  /// Тень под стеклянной панелью.
  final Color shadow;

  /// Панель оболочки поверх света игр — нарочно неплотная: заливка в упор
  /// погасила бы единственный цвет в окне.
  final double shellOpacity;

  /// Подложка панели инструментов библиотеки.
  final double toolbarOpacity;

  /// Карточка раздела.
  final double cardOpacity;

  /// Заливка карточки Material (`Card`) — плотнее панели разделов: на ней
  /// стоят строки очереди и снимков, и сквозь неё не должно читаться
  /// окружение. Прежде это было ветвление `isDark ? 0.82 : 0.9` в теме.
  final double materialCardOpacity;

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

  /// Тень обоймы разделов: размытие и сдвиг вниз.
  final double railShadowBlur;
  final double railShadowDrop;

  /// Тень крупного кадра библиотеки. Ночью это тень поднятого предмета —
  /// длинная и мягкая: кадр лежит над корпусом, а не вровень с ним.
  final double frameShadowBlur;
  final double frameShadowDrop;

  static const arclight = HardwareSurfaceTheme(
    shadow: Color(0x8C000000),
    shellOpacity: 0.62,
    toolbarOpacity: 0.72,
    cardOpacity: 0.62,
    materialCardOpacity: 0.82,
    readoutOpacity: 0.7,
    scrimOpacity: 0.72,
    ambientStrength: 1,
    vignetteOpacity: 0.62,
    railShadowBlur: 22,
    railShadowDrop: 10,
    frameShadowBlur: 54,
    frameShadowDrop: 26,
  );

  static const cartridge = HardwareSurfaceTheme(
    shadow: Color(0x578A8574),
    shellOpacity: 0.78,
    toolbarOpacity: 0.84,
    cardOpacity: 0.74,
    materialCardOpacity: 0.9,
    readoutOpacity: 0.6,
    scrimOpacity: 0.82,
    ambientStrength: 0.4,
    vignetteOpacity: 0.14,
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
    shadow,
    shellOpacity,
    toolbarOpacity,
    cardOpacity,
    materialCardOpacity,
    readoutOpacity,
    scrimOpacity,
    ambientStrength,
    vignetteOpacity,
    railShadowBlur,
    railShadowDrop,
    frameShadowBlur,
    frameShadowDrop,
  ];

  @override
  HardwareSurfaceTheme copyWith({double? shellOpacity}) => HardwareSurfaceTheme(
    shadow: shadow,
    shellOpacity: shellOpacity ?? this.shellOpacity,
    toolbarOpacity: toolbarOpacity,
    cardOpacity: cardOpacity,
    materialCardOpacity: materialCardOpacity,
    readoutOpacity: readoutOpacity,
    scrimOpacity: scrimOpacity,
    ambientStrength: ambientStrength,
    vignetteOpacity: vignetteOpacity,
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
      shadow: Color.lerp(shadow, other.shadow, t)!,
      shellOpacity: mix(shellOpacity, other.shellOpacity),
      toolbarOpacity: mix(toolbarOpacity, other.toolbarOpacity),
      cardOpacity: mix(cardOpacity, other.cardOpacity),
      materialCardOpacity: mix(materialCardOpacity, other.materialCardOpacity),
      readoutOpacity: mix(readoutOpacity, other.readoutOpacity),
      scrimOpacity: mix(scrimOpacity, other.scrimOpacity),
      ambientStrength: mix(ambientStrength, other.ambientStrength),
      vignetteOpacity: mix(vignetteOpacity, other.vignetteOpacity),
      railShadowBlur: mix(railShadowBlur, other.railShadowBlur),
      railShadowDrop: mix(railShadowDrop, other.railShadowDrop),
      frameShadowBlur: mix(frameShadowBlur, other.frameShadowBlur),
      frameShadowDrop: mix(frameShadowDrop, other.frameShadowDrop),
    );
  }
}
