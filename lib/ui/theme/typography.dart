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
/// **Роль по месту правят только цветом.** Из ста тридцати трёх
/// употреблений ролей два десятка добавляли по месту жирность, разрядку
/// и межстрочие, и роль расползалась так же, как прежде числа: у подписи
/// «жирнее обычного» было три разных набора. Нужен другой облик — это
/// другая роль здесь, и страж темы следит за этим.
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
  /// Цифры табличные — здесь почти всегда числа, и соседние строки
  /// списка должны стоять ими в столбик.
  TextStyle get captionMuted => TextStyle(
    fontSize: 12,
    color: _colors.textSecondary,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Мелкая подпись с упором: исход переноса, число на вкладке полки,
  /// вердикт обзоров.
  TextStyle get captionStrong =>
      const TextStyle(fontSize: 12, fontWeight: FontWeight.w600);

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

  /// Предупреждение, которое нельзя пропустить: о том, что затрёт прогресс.
  TextStyle get alert => warning.copyWith(fontWeight: FontWeight.w600);

  /// Метка на корпусе: моно, капс, с разрядкой — как подпись на панели
  /// прибора. До роли она разошлась сама собой: 8.5, 9, 9.5 и 10 точек,
  /// разрядка от 0.6 до 1.6, в двух местах и вовсе не моно. Она же —
  /// надстрочник раздела и крупного кадра: прежде тот был своей ролью на
  /// полточки крупнее и на ступень жирнее, то есть тем самым расхождением,
  /// ради которого роли и заводили. Цвет над показанием приглушённый, над
  /// разделом его задаёт место: фирменный в обойме, золото на кадре.
  TextStyle get label => TextStyle(
    fontFamily: EvaporateTheme.monoFontFamily,
    fontSize: 9,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    color: _colors.textSecondary,
  );

  /// Метка в строке состояния: разрядка вдвое уже — там тесно.
  TextStyle get statusLabel => label.copyWith(letterSpacing: 0.7);

  /// Число на метке очереди: кегль метки, но без разрядки — это число, а
  /// не надпись капсом, и разрядка развела бы цифры двузначного.
  TextStyle get badge => label.copyWith(letterSpacing: 0);

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

  /// Путь во второй строке плотного списка.
  TextStyle get pathSmall => path.copyWith(fontSize: 11.5);

  /// Строки журнала: мелкий моно с воздухом между строками — журнал
  /// читают подряд, а не выхватывают одну строку.
  TextStyle get log => pathSmall.copyWith(height: 1.5);

  /// Пояснение основным кеглем, абзацем: текст диалога, а не подпись к
  /// органу. Цвет наследует — это то, что человек читает, а не оглядывает.
  TextStyle get prose => const TextStyle(fontSize: 13, height: 1.5);

  /// Число в строке: размер, счётчик, доля. Моно с табличными цифрами, но
  /// кеглем строки, а не показания.
  TextStyle get figure => const TextStyle(
    fontFamily: EvaporateTheme.monoFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Надпись на плашке: состояние, оценка, исход переноса.
  TextStyle get chip =>
      const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600);

  /// Самое мелкое: метка правила, подпись клавиши геймпада.
  TextStyle get tag => const TextStyle(fontSize: 10.5, height: 1.3);

  /// Самое мелкое с упором: знак кнопки геймпада на плашке, надпись
  /// поверх обложки.
  TextStyle get tagStrong => tag.copyWith(fontWeight: FontWeight.w600);

  /// Вкладка полки: кегль строки, чуть разряжен, выбранная — жирнее.
  TextStyle get tab => const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  /// Выбранная вкладка полки.
  TextStyle get tabActive => tab.copyWith(fontWeight: FontWeight.w700);

  /// Надпись на главной клавише — широким шрифтом корпуса.
  TextStyle get keycap => const TextStyle(
    fontFamily: EvaporateTheme.displayFontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.3,
  );

  /// Заголовок диалога и крупной заслонки.
  TextStyle get title =>
      const TextStyle(fontSize: 17, fontWeight: FontWeight.w600);

  /// Заголовок карточки: имя задачи, раздел внутри карточки.
  TextStyle get subtitle =>
      const TextStyle(fontSize: 15, fontWeight: FontWeight.w600);

  /// Заголовок страницы игры.
  TextStyle get pageTitle =>
      const TextStyle(fontSize: 24, fontWeight: FontWeight.w700);
}

/// Короткий доступ к ролям текста: `context.text.caption`.
extension EvaporateTypographyAccess on BuildContext {
  EvaporateTypography get text => EvaporateTypography(colors);
}
