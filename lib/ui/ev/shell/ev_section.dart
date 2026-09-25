import '../../../l10n/app_localizations.dart';
import '../widgets/ev_icon.dart';

/// Разделы приложения в порядке обхода по `Ctrl+Tab` и цифровым клавишам.
///
/// Первые четыре — основная навигация в верхней части рейла; «Друзья» стоят
/// ниже разделителем, «Профиль» открывается аватаром.
enum EvSection {
  library(EvIcons.library),
  downloads(EvIcons.download),
  saves(EvIcons.saves),
  settings(EvIcons.settings),
  friends(EvIcons.friends),
  profile(EvIcons.friends);

  const EvSection(this.icon);

  final String icon;

  /// Основная навигация: верхняя группа рейла.
  static const primary = [library, downloads, saves, settings];

  /// Имя раздела на языке окна: крошка, подсказки рейла, диктор.
  String labelOf(L l) => switch (this) {
    library => l.library,
    downloads => l.downloads,
    saves => l.saves,
    settings => l.settings,
    friends => l.evSectionFriends,
    profile => l.evSectionProfile,
  };

  /// Номер на клавиатуре — тот же, что в строке подсказок прототипа.
  int get hotkey => index + 1;

  EvSection get next => values[(index + 1) % values.length];

  EvSection get previous => values[(index - 1 + values.length) % values.length];
}
