import 'package:flutter/widgets.dart';

/// Сколько экрана над местом раздела и под ним закрыто полосами каркаса.
///
/// Раздел стоит между верхней полосой и строкой подсказок
/// (`docs/decisions/0012`), а полосы — стекло: сквозь него видно то, что
/// уходит за край раздела. Прокрутке, которая уходит под них целиком
/// (`ChromeScrollView`), надо знать, насколько выходить за своё место и на
/// сколько отступать, подводя к выбранному.
///
/// Отступы `MediaQuery` для этого не годятся: каркас их у разделов
/// снимает — прежние страницы о полосах не знают и отступали бы дважды.
class ChromeOverlap extends InheritedWidget {
  const ChromeOverlap({super.key, required this.insets, required super.child});

  /// Сверху — верхняя полоса, снизу — строка подсказок; по бокам полос нет.
  final EdgeInsets insets;

  /// Без каркаса полос нет: прокрутка остаётся в своих границах.
  static EdgeInsets of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChromeOverlap>()?.insets ??
      EdgeInsets.zero;

  @override
  bool updateShouldNotify(ChromeOverlap oldWidget) =>
      insets != oldWidget.insets;
}
