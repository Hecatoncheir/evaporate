import 'package:flutter/widgets.dart';

/// Что помещается на клавише обоймы при нынешней её ширине.
class RackFit {
  const RackFit({
    required this.width,
    required this.showLabels,
    required this.showBadge,
  });

  /// Полная ширина клавиши с подписью.
  static const fullWidth = 130.0;

  /// Ниже этой ширины подпись не влезает и остаётся один значок.
  static const labelWidth = 124.0;

  /// Ниже этой — не влезает и метка очереди.
  static const badgeWidth = 58.0;

  /// Собственные поле и кант обоймы: место под клавиши меньше на столько.
  static const chrome = 8.0;

  /// Сколько места досталось одной клавише.
  ///
  /// Делим ровно то, что дали, за вычетом [chrome]: забыть про него — те
  /// самые восемь точек переполнения. Округлять вверх нельзя: переполнение
  /// на две точки выглядит так же плохо, как на двадцать.
  factory RackFit.forRack(BoxConstraints box, int buttons) {
    final room = box.maxWidth.isFinite
        ? box.maxWidth - chrome
        : buttons * fullWidth;
    final per = room <= 0 ? 0.0 : room / buttons;
    return RackFit(
      width: per < fullWidth ? per : fullWidth,
      showLabels: per >= labelWidth,
      showBadge: per >= badgeWidth,
    );
  }

  final double width;
  final bool showLabels;
  final bool showBadge;
}
