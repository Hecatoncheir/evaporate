import 'package:flutter/material.dart';

import '../../models/app_theme_mode.dart';

/// Выбор схемы из настроек — на язык Flutter.
///
/// Переходник живёт здесь, а не в модели: настройки читают и пишут там,
/// где Flutter нет вовсе, а `ThemeMode` нужен ровно одному месту — сборке
/// `MaterialApp`.
extension AppThemeModeMaterial on AppThemeMode {
  ThemeMode get material => switch (this) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
}
