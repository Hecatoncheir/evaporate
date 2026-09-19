import 'package:flutter/material.dart';

import 'foil_motion.dart';

/// Раздаёт ход перелива вниз по дереву: блик рисует `FoilSurface`, а лежит
/// она глубоко внутри карточки, под обложкой и её значками.
class FoilScope extends InheritedWidget {
  const FoilScope({super.key, required this.motion, required super.child});

  final FoilMotion motion;

  @override
  bool updateShouldNotify(FoilScope oldWidget) => motion != oldWidget.motion;
}
