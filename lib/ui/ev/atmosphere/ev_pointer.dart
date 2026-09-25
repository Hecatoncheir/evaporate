import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Курсор над окном в долях его размера — один на всё окно, как `mx, my`
/// в прототипе: за ним сдвигаются и плюм пара, и слои обложки героя.
///
/// Значение догоняет цель со сглаживанием прототипа — 5,5 % пути за кадр
/// при 60 Гц, пересчитанные во время, чтобы на 120 Гц курсор не догонялся
/// вдвое быстрее. Шаги делает атмосфера, пока ей или слушателям нужны кадры.
class EvPointer extends ChangeNotifier implements ValueListenable<Offset> {
  EvPointer([Offset initial = const Offset(0.5, 0.4)])
    : _value = initial,
      target = initial;

  /// Ближе этого значение считается догнавшим: на слое глубиной 30 px
  /// это сотая доля пикселя.
  static const settleDistance = 5e-4;

  Offset _value;

  /// Куда смотрит курсор. Слушатели узнают об этом со следующим шагом.
  Offset target;

  @override
  Offset get value => _value;

  /// Значение ещё не догнало цель.
  bool get settling => _value != target;

  /// За значением кто-то следит — кадры нужны и без живого фона.
  bool get isWatched => hasListeners;

  /// Сдвинуть значение к цели на [seconds] секунд сглаживания.
  void advance(double seconds) {
    if (!settling) return;
    final k = 1 - math.pow(1 - 0.055, seconds * 60).toDouble();
    var next = Offset.lerp(_value, target, k)!;
    if ((target - next).distance <= settleDistance) next = target;
    if (next == _value) return;
    _value = next;
    notifyListeners();
  }

  /// Поставить курсор сразу, без сглаживания.
  void jumpTo(Offset value) {
    target = value;
    if (value == _value) return;
    _value = value;
    notifyListeners();
  }
}
