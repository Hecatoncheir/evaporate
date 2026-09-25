import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../design/tokens.dart';

/// Размеры библиотеки для окна данного размера — ступени прототипа.
///
/// В CSS правила объявлены в таком порядке, и позднее сильнее раннего:
/// узкое окно (до 760), низкое (до 800), низкое и не шире 1120, широкое
/// (от 1800), шире 2200. Поэтому на широком низком окне герой высокий,
/// а обложки — широкие: правило ширины объявлено позже.
@immutable
class EvLibraryLayout {
  const EvLibraryLayout._({
    required this.gutter,
    required this.low,
    required this.wide,
    required this.heroHeight,
    required this.titleSize,
    required this.bodySide,
    required this.bodyBottom,
    required this.bodyGap,
    required this.blurbSize,
    required this.blurbChars,
    required this.ctaTop,
    required this.buttonHeight,
    required this.sectionTop,
    required this.sectionHeadGap,
    required this.showSessions,
    required this.sessionMinWidth,
    required this.cardWidth,
    required this.shelfBottom,
    required this.sideWidth,
    required this._bodyShare,
    required this._bodyCap,
  });

  factory EvLibraryLayout.of(Size window) {
    final vw = window.width / 100, vh = window.height / 100;
    final narrow = window.width < EvSpace.narrowBreakpoint;
    final low = window.height <= 800;
    final wide = window.width >= 1800;
    final widest = window.width >= 2200;

    double clamp(double min, double value, double max) =>
        value.clamp(min, max).toDouble();

    var heroHeight = clamp(340, 52 * vh, 520);
    var titleSize = clamp(34, 5.4 * vw, 68);
    var bodySide = clamp(20, 3.4 * vw, 44);
    var bodyBottom = clamp(20, 3.4 * vw, 40);
    var bodyShare = .72, bodyCap = 620.0;
    var blurbSize = 14.0;
    var blurbChars = 46;
    var cardWidth = 178.0;
    var sessionMinWidth = 268.0;

    if (narrow) {
      heroHeight = math.min(58 * vh, 400);
      bodyShare = 1;
      bodyCap = double.infinity;
    }
    if (low) {
      heroHeight = 300;
      titleSize = clamp(28, 3.4 * vw, 44);
      bodyBottom = 18;
      bodySide = clamp(18, 2.6 * vw, 32);
      blurbSize = 13;
      cardWidth = window.width <= 1120 ? 134 : 152;
    }
    if (wide) {
      heroHeight = clamp(520, 42 * vh, 660);
      titleSize = clamp(56, 3.6 * vw, 82);
      bodyShare = .64;
      bodyCap = 760;
      blurbSize = 15.5;
      blurbChars = 52;
      cardWidth = 206;
      sessionMinWidth = 330;
    }
    if (widest) {
      bodyShare = .58;
      bodyCap = 840;
      cardWidth = 224;
    }

    return EvLibraryLayout._(
      gutter: EvSpace.gutterFor(window),
      low: low,
      wide: wide,
      heroHeight: heroHeight,
      titleSize: titleSize,
      bodySide: bodySide,
      bodyBottom: bodyBottom,
      bodyGap: low ? 11 : 14,
      blurbSize: blurbSize,
      blurbChars: blurbChars,
      ctaTop: low ? 2 : 4,
      buttonHeight: low ? 50 : 56,
      sectionTop: low ? 20 : 30,
      sectionHeadGap: low ? 12 : 16,
      // «Продолжить» складывается: на низком окне герой и есть эта кнопка
      showSessions: !low,
      sessionMinWidth: sessionMinWidth,
      cardWidth: cardWidth,
      shelfBottom: low ? 12 : 18,
      sideWidth: widest
          ? 420
          : wide
          ? 384
          : 0,
      bodyShare: bodyShare,
      bodyCap: bodyCap,
    );
  }

  /// Боковое поле экрана.
  final double gutter;

  /// Окно до 800 по высоте.
  final bool low;

  /// Окно от 1800 по ширине.
  final bool wide;

  final double heroHeight;

  /// Кегль заголовка героя.
  final double titleSize;

  /// Отступ текста героя от боковых кромок.
  final double bodySide;

  /// Отступ текста героя от нижней кромки.
  final double bodyBottom;

  /// Шаг между строками текста героя.
  final double bodyGap;

  final double blurbSize;

  /// Длина строки описания в знаках — `max-width: 46ch`.
  final int blurbChars;

  /// Добавка над кнопками к обычному шагу.
  final double ctaTop;

  /// Высота «Играть» и «Подробнее».
  final double buttonHeight;

  /// Отступ над заголовком раздела.
  final double sectionTop;

  /// Отступ под заголовком раздела.
  final double sectionHeadGap;

  final bool showSessions;

  /// Наименьшая ширина строки «Продолжить» — колонки `auto-fill`.
  final double sessionMinWidth;

  /// Ширина обложки на полке.
  final double cardWidth;

  /// Отступ под полкой.
  final double shelfBottom;

  /// Правая колонка: друзья и загрузки. `0` — колонки нет.
  final double sideWidth;

  final double _bodyShare;
  final double _bodyCap;

  /// Наибольшая ширина текста героя шириной [heroWidth]:
  /// `min(620px, 72%)` и ступени шире.
  double bodyMaxWidth(double heroWidth) =>
      math.min(_bodyCap, heroWidth * _bodyShare);
}
