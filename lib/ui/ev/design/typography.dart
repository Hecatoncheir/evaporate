import 'package:flutter/widgets.dart';

/// Шрифтовая пара. Кириллица нарисована во всех трёх — это было условием
/// выбора, интерфейс русскоязычный.
///
/// * **Unbounded** — дисплей: заголовки, крупные числа, логотип.
/// * **Onest** — интерфейс: всё остальное.
/// * **JetBrains Mono** — данные: скорости, пиры, хеши, подсказки клавиш.
///
/// Семейства лежат в сборке (`pubspec.yaml`, `assets/fonts/`), а не
/// скачиваются `google_fonts`, как в прототипе: в приложении это был бы
/// запрос к Google на каждой машине мимо согласия человека, файлы в его
/// папке данных даже у `--smoke` и запасной шрифт без сети. Сторожит
/// `bundled_fonts_test.dart`.
@immutable
class EvType {
  const EvType(this.ink, this.ink2, this.ink3, this.ink4);

  /// Семейства из `pubspec.yaml`. Unbounded и JetBrains Mono — вариативные,
  /// Onest — три начертания (400, 500, 600): других интерфейс не просит.
  static const uiFamily = 'Onest';
  static const displayFamily = 'Unbounded';
  static const monoFamily = 'JetBrains Mono';

  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color ink4;

  /// Тот же стиль в семействе интерфейса и, если задано, другом
  /// начертании.
  ///
  /// В прототипе через эти три фабрики шли все отклонения от базового
  /// веса: у `google_fonts` начертание зашито в имя семейства, и
  /// `copyWith(fontWeight: …)` его не меняло. Семейства из сборки
  /// слушаются веса и так, а фабрики остались — ими написан весь код
  /// прототипа.
  ///
  /// Остальные параметры прокинуты, чтобы правка веса и правка кегля или
  /// цвета не расходились по двум вызовам.
  TextStyle ui(
    TextStyle base, {
    FontWeight? weight,
    double? size,
    Color? color,
    double? letterSpacing,
  }) => base.copyWith(
    fontFamily: uiFamily,
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
  }) => base.copyWith(
    fontFamily: displayFamily,
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
  }) => base.copyWith(
    fontFamily: monoFamily,
    fontWeight: weight,
    fontSize: size,
    color: color,
    letterSpacing: letterSpacing,
  );

  /// Заголовок героя. Лёгкое начертание в крупном кегле — характер системы.
  TextStyle display(double size) => TextStyle(
    fontFamily: displayFamily,
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
  TextStyle get section => TextStyle(
    fontFamily: displayFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.6,
    color: ink,
  );

  /// Название игры, строки списков.
  TextStyle get title => TextStyle(
    fontFamily: uiFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.08,
    color: ink,
  );

  // Разрядка задана явно: под Material текст без неё наследует 0.25
  // из bodyMedium и выходит шире прототипа — описание героя переносилось
  // на лишнюю строку.
  TextStyle get body => TextStyle(
    fontFamily: uiFamily,
    fontSize: 14,
    height: 1.5,
    letterSpacing: 0,
    color: ink2,
  );

  TextStyle get bodySmall => TextStyle(
    fontFamily: uiFamily,
    fontSize: 12.5,
    height: 1.45,
    letterSpacing: 0,
    color: ink3,
  );

  /// Надпись над заголовком и подписи панелей.
  TextStyle get label => TextStyle(
    fontFamily: monoFamily,
    fontSize: 10.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 2.1,
    color: ink4,
  );

  /// Числа. Везде, где цифры выстраиваются в колонку, — моноширинные.
  TextStyle get data => TextStyle(
    fontFamily: monoFamily,
    fontSize: 11.5,
    letterSpacing: 0,
    color: ink3,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  TextStyle get dataStrong => mono(data, weight: FontWeight.w500, color: ink);

  /// Крупное число в панели.
  TextStyle big(double size) => TextStyle(
    fontFamily: displayFamily,
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
