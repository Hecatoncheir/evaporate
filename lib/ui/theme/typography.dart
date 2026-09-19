import 'package:flutter/material.dart';

import 'evaporate_theme.dart';
import 'palette.dart';

/// Роли текста: кегль, начертание и цвет по смыслу, а не числами по месту.
///
/// Разбросанные по виджетам `TextStyle(fontSize: 12.5, …)` расходились сами
/// собой — у одной роли «пояснение» было три разных набора, — ровно тот
/// довод, которым в `motion.dart` обоснованы токены длительностей.
///
/// Роли выведены из того, что уже употреблялось чаще всего. Цвет роль несёт
/// только там, где он часть смысла: приглушённое пояснение, предупреждение.
/// Обычный текст цвета не задаёт и наследует его — на заливке клавиши это
/// цвет надписи на заливке, и роль с жёстким цветом перекрасила бы такие
/// подписи.
///
/// Не `ThemeExtension`, а производное от палитры: при плавной смене схемы
/// роли идут за уже смешанной палитрой сами, и отдельного `lerp` на каждое
/// поле им не нужно.
class EvaporateTypography {
  const EvaporateTypography(this._colors);

  final EvaporatePalette _colors;

  /// Основной текст строк и подписей настроек.
  TextStyle get body => const TextStyle(fontSize: 13);

  /// Заголовок строки списка: имя правила, снимка, папки.
  TextStyle get bodyStrong =>
      const TextStyle(fontSize: 13, fontWeight: FontWeight.w600);

  /// Основной кегль, но второстепенный смысл.
  TextStyle get bodyMuted =>
      TextStyle(fontSize: 13, color: _colors.textSecondary);

  /// Мелкая подпись без приглушения: подстрочник, значение рядом с меткой.
  TextStyle get caption => const TextStyle(fontSize: 12);

  /// Мелкая приглушённая подпись: размер, время, путь рядом с названием.
  TextStyle get captionMuted =>
      TextStyle(fontSize: 12, color: _colors.textSecondary);

  /// Короткое пояснение в одну-две строки под органом управления.
  TextStyle get note => TextStyle(fontSize: 12.5, color: _colors.textSecondary);

  /// Пояснение абзацем: межстрочный воздух, чтобы несколько строк читались.
  TextStyle get paragraph =>
      TextStyle(fontSize: 12.5, height: 1.5, color: _colors.textSecondary);

  /// Совсем мелкое: вторая строка плотного списка.
  TextStyle get small => const TextStyle(fontSize: 11.5);

  /// Предупреждение под полем или в карточке.
  TextStyle get warning =>
      TextStyle(fontSize: 12, height: 1.4, color: _colors.warning);

  /// Метка на корпусе: моно, капс, с разрядкой — как подпись на панели
  /// прибора. До роли она разошлась сама собой: 8.5, 9, 9.5 и 10 точек,
  /// разрядка от 0.6 до 1.6, в двух местах и вовсе не моно.
  TextStyle get label => TextStyle(
    fontFamily: EvaporateTheme.monoFontFamily,
    fontSize: 9,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    color: _colors.textSecondary,
  );

  /// Надстрочник раздела и крупного кадра — метка покрупнее и плотнее.
  /// Цвет задаёт место: фирменный в обойме, золото на кадре.
  TextStyle get eyebrow => const TextStyle(
    fontFamily: EvaporateTheme.monoFontFamily,
    fontSize: 9.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.6,
  );

  /// Показание: моно с табличными цифрами — иначе строка дёргается, когда
  /// меняется одна цифра.
  TextStyle get readout => const TextStyle(
    fontFamily: EvaporateTheme.monoFontFamily,
    fontSize: 14,
    height: 1,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Главное показание раздела — крупно.
  TextStyle get readoutLarge => readout.copyWith(fontSize: 21);

  /// Пути и шаблоны путей — моношириной, иначе их не сверить глазом.
  TextStyle get path => TextStyle(
    fontSize: 12,
    fontFamily: EvaporateTheme.monoFontFamily,
    color: _colors.textSecondary,
  );
}

/// Короткий доступ к ролям текста: `context.text.caption`.
extension EvaporateTypographyAccess on BuildContext {
  EvaporateTypography get text => EvaporateTypography(colors);
}
