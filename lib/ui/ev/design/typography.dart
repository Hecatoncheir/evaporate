import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

/// Шрифтовая пара. Кириллица нарисована во всех трёх — это было условием
/// выбора, интерфейс русскоязычный.
///
/// * **Unbounded** — дисплей: заголовки, крупные числа, логотип.
/// * **Onest** — интерфейс: всё остальное.
/// * **JetBrains Mono** — данные: скорости, пиры, хеши, подсказки клавиш.
@immutable
class EvType {
  const EvType(this.ink, this.ink2, this.ink3, this.ink4);

  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color ink4;

  /// Тот же стиль в другом начертании.
  ///
  /// `copyWith(fontWeight: …)` начертания не меняет: google_fonts кладёт
  /// в стиль `fontFamily: 'Onest_500'` и подгружает только это начертание.
  /// Движок остаётся с ним: либо подделывает насыщенность, либо молча
  /// игнорирует просьбу. Настоящее начертание рождается лишь из повторного
  /// вызова фабрики — через него и идут все отклонения от базового веса.
  ///
  /// Остальные параметры прокинуты, чтобы правка веса и правка кегля или
  /// цвета не расходились по двум вызовам.
  TextStyle ui(
    TextStyle base, {
    FontWeight? weight,
    double? size,
    Color? color,
    double? letterSpacing,
  }) => GoogleFonts.onest(
    textStyle: base,
    fontWeight: weight,
    fontSize: size,
    color: color,
    letterSpacing: letterSpacing,
  );

  /// То же для дисплейного семейства. См. [ui].
  TextStyle dsp(
    TextStyle base, {
    FontWeight? weight,
    double? size,
    Color? color,
    double? letterSpacing,
  }) => GoogleFonts.unbounded(
    textStyle: base,
    fontWeight: weight,
    fontSize: size,
    color: color,
    letterSpacing: letterSpacing,
  );

  /// То же для моноширинного семейства. См. [ui].
  TextStyle mono(
    TextStyle base, {
    FontWeight? weight,
    double? size,
    Color? color,
    double? letterSpacing,
  }) => GoogleFonts.jetBrainsMono(
    textStyle: base,
    fontWeight: weight,
    fontSize: size,
    color: color,
    letterSpacing: letterSpacing,
  );

  /// Заголовок героя. Лёгкое начертание в крупном кегле — характер системы.
  TextStyle display(double size) => GoogleFonts.unbounded(
    fontSize: size,
    fontWeight: FontWeight.w300,
    height: 0.94,
    letterSpacing: size * -0.022,
    color: ink,
  );

  /// Ударная часть заголовка.
  TextStyle displayBold(double size) =>
      dsp(display(size), weight: FontWeight.w800);

  /// Заголовок раздела: капс с разрядкой.
  TextStyle get section => GoogleFonts.unbounded(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.6,
    color: ink,
  );

  /// Название игры, строки списков.
  TextStyle get title => GoogleFonts.onest(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.08,
    color: ink,
  );

  // Разрядка задана явно: под Material текст без неё наследует 0.25
  // из bodyMedium и выходит шире прототипа — описание героя переносилось
  // на лишнюю строку.
  TextStyle get body => GoogleFonts.onest(
    fontSize: 14,
    height: 1.5,
    letterSpacing: 0,
    color: ink2,
  );

  TextStyle get bodySmall => GoogleFonts.onest(
    fontSize: 12.5,
    height: 1.45,
    letterSpacing: 0,
    color: ink3,
  );

  /// Надпись над заголовком и подписи панелей.
  TextStyle get label => GoogleFonts.jetBrainsMono(
    fontSize: 10.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 2.1,
    color: ink4,
  );

  /// Числа. Везде, где цифры выстраиваются в колонку, — моноширинные.
  TextStyle get data => GoogleFonts.jetBrainsMono(
    fontSize: 11.5,
    letterSpacing: 0,
    color: ink3,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  TextStyle get dataStrong => mono(data, weight: FontWeight.w500, color: ink);

  /// Крупное число в панели.
  TextStyle big(double size) => GoogleFonts.unbounded(
    fontSize: size,
    fontWeight: FontWeight.w300,
    height: 1,
    letterSpacing: size * -0.03,
    color: ink,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static EvType lerp(EvType a, EvType b, double t) => EvType(
    Color.lerp(a.ink, b.ink, t)!,
    Color.lerp(a.ink2, b.ink2, t)!,
    Color.lerp(a.ink3, b.ink3, t)!,
    Color.lerp(a.ink4, b.ink4, t)!,
  );
}
