import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ход перелива: фаза бега блика и сила эффекта, от нуля в покое до
/// единицы у выбранной карточки.
///
/// Не виджет, а `ChangeNotifier`: на него подписаны сразу двое — карточка
/// своей перспективой и поверхность своим бликом, — и перестраивать ради
/// каждого кадра поддерево не нужно ни тому, ни другому.
class FoilMotion extends ChangeNotifier {
  double phase = 0;
  double strength = 0;
  bool tilt = true;
  bool foil = true;
  bool distortion = false;
  double get amount => Curves.easeInOut.transform(strength);
  Matrix4 get perspective {
    final matrix = Matrix4.identity();
    if (strength == 0) return matrix;
    if (tilt) {
      matrix
        ..setEntry(3, 2, 0.0015)
        ..rotateX(math.sin(phase) * 0.11 * amount)
        ..rotateY(math.sin(phase + math.pi / 3) * 0.16 * amount);
    }
    if (distortion) {
      // Пробегающее сжатие в момент прихода фокуса и мягкое покачивание
      // следом. Масштабы взаимно обратны: площадь сохраняется, и сетка от
      // деформации не разъезжается.
      final pulse = math.sin(strength * math.pi * 2) * (1 - strength);
      final stretch = 1 + pulse * 0.065 + math.sin(phase * 2) * 0.012 * amount;
      final liquid = Matrix4.identity()
        ..setEntry(0, 0, stretch)
        ..setEntry(1, 1, 1 / stretch)
        ..setEntry(
          0,
          1,
          pulse * 0.035 + math.sin(phase * 1.7) * 0.009 * amount,
        );
      matrix.multiply(liquid);
    }
    return matrix;
  }

  void changed() => notifyListeners();
}
