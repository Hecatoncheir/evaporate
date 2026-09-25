import 'package:flutter/material.dart';

import 'theme.dart';

/// Облик приложения: тема и потолок радиуса.
///
/// Живёт над `MaterialApp`, поэтому его видят все маршруты — и каркас,
/// и настройки, и галерея компонентов — без протаскивания через параметры.
class EvAppearance extends ChangeNotifier {
  EvAppearance({this._skin = EvSkin.magma, this._geometry = EvGeometry.tight});

  EvSkin _skin;
  EvGeometry _geometry;

  EvSkin get skin => _skin;
  set skin(EvSkin value) {
    if (value == _skin) return;
    _skin = value;
    notifyListeners();
  }

  EvGeometry get geometry => _geometry;
  set geometry(EvGeometry value) {
    if (value == _geometry) return;
    _geometry = value;
    notifyListeners();
  }

  ThemeData get theme => buildEvTheme(skin: _skin, geometry: _geometry);
}

class EvAppearanceScope extends InheritedNotifier<EvAppearance> {
  const EvAppearanceScope({
    super.key,
    required EvAppearance appearance,
    required super.child,
  }) : super(notifier: appearance);

  static EvAppearance of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<EvAppearanceScope>()!
      .notifier!;
}
