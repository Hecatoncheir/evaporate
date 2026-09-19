import 'package:flutter/material.dart';

import 'liquid_selection_path.dart';

/// Где сейчас капля: откуда едет, куда и насколько доехала.
///
/// Читают её двое — рисовальщик заливки и подписи, которых она накрывает, —
/// и оба только читают. Поля лежали приватными в `State`, а чужие классы
/// доставали их сквозь приватность: пока всё в одном файле, это законно, но
/// разложить такое по файлам уже нельзя. Здесь то же самое, но названо
/// вслух: пишет один, владелец, а наружу уходит готовый контур.
class LiquidGeometry {
  LiquidGeometry({
    required this.viewport,
    required this.repaint,
    required this.travel,
  });

  /// Подложка, в координатах которой лежат прямоугольники.
  final GlobalKey viewport;

  /// Тикает на каждом кадре перехода и на каждом новом замере.
  final Listenable repaint;

  /// Ход перехода. Живёт у владельца — геометрия только читает его.
  final Animation<double> travel;
  Rect? _from;
  Rect? _to;
  double _radius = 18;

  /// Куда капля едет — или где стоит. `null`, когда обнимать нечего.
  Rect? get target => _to;

  /// Сколько пути пройдено: 0 — у прежнего места, 1 — доехала.
  double get progress => travel.value;

  void moveTo({
    required Rect? from,
    required Rect? to,
    required double radius,
  }) {
    _from = from;
    _to = to;
    _radius = radius;
  }

  /// Контур капли прямо сейчас. `null`, когда её нет.
  Path? path() {
    final to = _to;
    if (to == null) return null;
    return liquidSelectionPath(_from ?? to, to, progress, _radius);
  }
}
