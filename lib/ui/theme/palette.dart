import 'package:flutter/material.dart';

/// Цвета приложения.
///
/// Раздаются через тему, а не константами: иначе светлая и тёмная схемы
/// не могли бы существовать одновременно. Берутся из контекста —
/// `context.colors.textSecondary`.
///
/// Две схемы — это два самостоятельных облика, а не одна палитра с
/// вывернутой яркостью. «Арклайт» (ночь) — чернильный корпус кинозала с
/// раскалённым оранжевым; «Картридж» (день) — светлый корпус
/// измерительного прибора с плоским насыщенным цветом. Осветлённая копия
/// ночной схемы выглядела бы выцветшей, и обратно — тоже.
class EvaporatePalette extends ThemeExtension<EvaporatePalette> {
  const EvaporatePalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.outline,
    required this.primary,
    required this.primaryFill,
    required this.onPrimary,
    required this.accent,
    required this.accentFill,
    required this.danger,
    required this.dangerFill,
    required this.onDanger,
    required this.warning,
    required this.textPrimary,
    required this.textSecondary,
    required this.railBackground,
    required this.selection,
    required this.onSelection,
    required this.glow,
    required this.depth,
    required this.shadow,
  });

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color outline;

  /// Фирменный цвет **для текста и значков**: им набраны надстрочные метки,
  /// проценты и состояния, поэтому он проверен по контрасту на подложках.
  final Color primary;

  /// Тот же цвет **для заливок**. Роли разделены не для красоты: насыщенный
  /// оранжевый Картриджа хорош как блок под надписью и не дотягивает до
  /// нормы как текст на светлом фоне. Один токен на две роли означал бы
  /// либо тусклые кнопки, либо нечитаемые подписи.
  final Color primaryFill;

  /// Что пишут поверх [primaryFill].
  final Color onPrimary;

  /// Служебный акцент для текста (скорости, ссылки, «готово»).
  final Color accent;

  /// Он же для заливок и светодиодов, где яркость важнее читаемости.
  final Color accentFill;

  /// Цвет необратимого **для текста**: «Удалить», «Отменить с файлами».
  final Color danger;

  /// Он же **для заливки** — клавиша подтверждения и сообщение об ошибке.
  /// Разведены по той же причине, что [primary] и [primaryFill]: красный,
  /// читаемый как текст на подложке, под надписью давал 2,7:1 в Картридже
  /// и около 3:1 у сообщения об ошибке в обеих схемах.
  final Color dangerFill;

  /// Что пишут поверх [dangerFill].
  final Color onDanger;
  final Color warning;
  final Color textPrimary;
  final Color textSecondary;
  final Color railBackground;

  /// Выбранное: капля выделения, выбранный сегмент, рамка фокуса.
  final Color selection;
  final Color onSelection;

  /// Ореол вокруг активного: в ночной схеме светится янтарь, в дневной
  /// **прозрачный** — светлый корпус не светится, он отбрасывает тень.
  final Color glow;

  /// «Толщина» под клавишей: кнопка стоит на своём тёмном торце и
  /// проваливается при нажатии. Ночью торец — остывающий низ того же
  /// огня, днём — тёмный край оранжевого. Под надписью этот цвет не
  /// лежит: на нём она не дотянула бы до нормы.
  final Color depth;

  /// Тень панелей: в ночи длинная и мягкая, днём короткая и жёсткая.
  final Color shadow;

  /// Все поля по порядку — для проверки, что `lerp` и `copyWith` не
  /// забыли ни одного: забытое в `lerp` поле молча застревает в прежней
  /// схеме при плавной смене.
  List<Object> get values => [
    brightness,
    background,
    surface,
    surfaceHigh,
    outline,
    primary,
    primaryFill,
    onPrimary,
    accent,
    accentFill,
    danger,
    dangerFill,
    onDanger,
    warning,
    textPrimary,
    textSecondary,
    railBackground,
    selection,
    onSelection,
    glow,
    depth,
    shadow,
  ];

  bool get isDark => brightness == Brightness.dark;

  /// «Арклайт»: почти чёрные чернила с уходом в фиолетовый, раскалённый
  /// оранжевый главного действия, янтарь выделения и холодный циан на
  /// показаниях. Цвет в интерфейс приносят обложки игр, поэтому сам корпус
  /// остаётся сдержанным.
  ///
  /// Значения — облик Magma из прототипа (`docs/decisions/0010`). Выделение
  /// взято янтарём, а не оранжевым главного действия: оранжевая капля
  /// сливалась бы с кромкой искр вокруг выбранной обложки. Третьего и
  /// четвёртого уровня чернил прототипа здесь нет: на подложках они не
  /// дотягивают до нормы текста, и приглушение остаётся ролью, а не цветом.
  static const dark = EvaporatePalette(
    brightness: Brightness.dark,
    background: Color(0xFF06060A),
    surface: Color(0xFF0E0F16),
    surfaceHigh: Color(0xFF15161F),
    outline: Color(0xFF22242F),
    primary: Color(0xFFFF7A18),
    primaryFill: Color(0xFFFF7A18),
    onPrimary: Color(0xFF170800),
    accent: Color(0xFF5EE7FF),
    accentFill: Color(0xFF5EE7FF),
    danger: Color(0xFFFF4D5E),
    dangerFill: Color(0xFFFF4D5E),
    onDanger: Color(0xFF0A0D11),
    warning: Color(0xFFFFC24D),
    textPrimary: Color(0xFFF2F3F7),
    textSecondary: Color(0xFFA8ACBD),
    railBackground: Color(0xFF0A0B11),
    selection: Color(0xFFFFC24D),
    onSelection: Color(0xFF0A0D11),
    glow: Color(0xFFFFC24D),
    depth: Color(0xFFC93A05),
    shadow: Color(0xB3000000),
  );

  /// «Картридж»: светлый корпус, плоский цвет без переходов и чёрные
  /// надписи на оранжевом — так подписывают органы управления на железе.
  static const light = EvaporatePalette(
    brightness: Brightness.light,
    background: Color(0xFFE4E1D8),
    surface: Color(0xFFF7F6F2),
    surfaceHigh: Color(0xFFD8D5CA),
    outline: Color(0xFFBCB7A9),
    primary: Color(0xFFA62C00),
    primaryFill: Color(0xFFFF4A17),
    onPrimary: Color(0xFF1F0800),
    accent: Color(0xFF006472),
    accentFill: Color(0xFF0090A8),
    danger: Color(0xFFA8231B),
    dangerFill: Color(0xFFA8231B),
    onDanger: Color(0xFFFFFFFF),
    warning: Color(0xFF7A5200),
    textPrimary: Color(0xFF16171A),
    textSecondary: Color(0xFF55585C),
    railBackground: Color(0xFFDAD7CD),
    selection: Color(0xFF16171A),
    onSelection: Color(0xFFF7F6F2),
    glow: Color(0x00000000),
    depth: Color(0xFFB22F08),
    shadow: Color(0x33000000),
  );

  @override
  EvaporatePalette copyWith({
    Brightness? brightness,
    Color? background,
    Color? surface,
    Color? surfaceHigh,
    Color? outline,
    Color? primary,
    Color? primaryFill,
    Color? onPrimary,
    Color? accent,
    Color? accentFill,
    Color? danger,
    Color? dangerFill,
    Color? onDanger,
    Color? warning,
    Color? textPrimary,
    Color? textSecondary,
    Color? railBackground,
    Color? selection,
    Color? onSelection,
    Color? glow,
    Color? depth,
    Color? shadow,
  }) {
    return EvaporatePalette(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      outline: outline ?? this.outline,
      primary: primary ?? this.primary,
      primaryFill: primaryFill ?? this.primaryFill,
      onPrimary: onPrimary ?? this.onPrimary,
      accent: accent ?? this.accent,
      accentFill: accentFill ?? this.accentFill,
      danger: danger ?? this.danger,
      dangerFill: dangerFill ?? this.dangerFill,
      onDanger: onDanger ?? this.onDanger,
      warning: warning ?? this.warning,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      railBackground: railBackground ?? this.railBackground,
      selection: selection ?? this.selection,
      onSelection: onSelection ?? this.onSelection,
      glow: glow ?? this.glow,
      depth: depth ?? this.depth,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  EvaporatePalette lerp(ThemeExtension<EvaporatePalette>? other, double t) {
    if (other is! EvaporatePalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return EvaporatePalette(
      // Яркость не смешивается: она переключается разом на середине.
      brightness: t < 0.5 ? brightness : other.brightness,
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceHigh: mix(surfaceHigh, other.surfaceHigh),
      outline: mix(outline, other.outline),
      primary: mix(primary, other.primary),
      primaryFill: mix(primaryFill, other.primaryFill),
      onPrimary: mix(onPrimary, other.onPrimary),
      accent: mix(accent, other.accent),
      accentFill: mix(accentFill, other.accentFill),
      danger: mix(danger, other.danger),
      dangerFill: mix(dangerFill, other.dangerFill),
      onDanger: mix(onDanger, other.onDanger),
      warning: mix(warning, other.warning),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      railBackground: mix(railBackground, other.railBackground),
      selection: mix(selection, other.selection),
      onSelection: mix(onSelection, other.onSelection),
      glow: mix(glow, other.glow),
      depth: mix(depth, other.depth),
      shadow: mix(shadow, other.shadow),
    );
  }
}
