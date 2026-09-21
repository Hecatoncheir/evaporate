import 'package:evaporate/l10n/app_localizations.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:flutter/material.dart';

/// Виджет в окружении приложения: тема, язык и `Scaffold` под ним.
///
/// Ровно это окружение выписывалось в двенадцати местах слово в слово —
/// шесть строк, одинаковых до запятой. Параметра здесь два, и оба нужны
/// настоящим тестам: схема (контраст меряют на обеих) и язык.
///
/// **Флагов сверх этого нет намеренно.** Обвязки, которые отличаются по
/// делу, — со своим `MediaQuery`, с `builder` рамки окна, без темы вовсе
/// ради чистого снимка отрисовки, — остались своими: общая функция с
/// флагом на каждый такой случай читалась бы хуже, чем шесть строк на
/// месте, и прятала бы то, ради чего тест своё окружение и завёл.
Widget hostWidget(
  Widget child, {
  ThemeData? theme,
  Locale locale = const Locale('ru'),
}) => MaterialApp(
  theme: theme ?? EvaporateTheme.dark(),
  localizationsDelegates: L.localizationsDelegates,
  supportedLocales: L.supportedLocales,
  locale: locale,
  home: Scaffold(body: child),
);
