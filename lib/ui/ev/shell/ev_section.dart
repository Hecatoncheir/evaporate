import '../widgets/ev_icon.dart';

/// Разделы приложения в порядке обхода по `Ctrl+Tab` и цифровым клавишам.
///
/// Первые четыре — основная навигация в верхней части рейла; «Друзья» стоят
/// ниже разделителем, «Профиль» открывается аватаром.
enum EvSection {
  library('Библиотека', EvIcons.library),
  downloads('Загрузки', EvIcons.download),
  saves('Сохранения', EvIcons.saves),
  settings('Настройки', EvIcons.settings),
  friends('Друзья', EvIcons.friends),
  profile('Профиль', EvIcons.friends);

  const EvSection(this.label, this.icon);

  final String label;
  final String icon;

  /// Основная навигация: верхняя группа рейла.
  static const primary = [library, downloads, saves, settings];

  /// Номер на клавиатуре — тот же, что в строке подсказок прототипа.
  int get hotkey => index + 1;

  EvSection get next => values[(index + 1) % values.length];

  EvSection get previous => values[(index - 1 + values.length) % values.length];
}
