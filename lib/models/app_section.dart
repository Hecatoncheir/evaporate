/// Разделы приложения — в порядке обоймы сверху.
///
/// Перечислением, а не числами: прежде их было двое — счёт `sectionCount`
/// в блоке и два параллельных списка подписей и значков в обойме, — да ещё
/// `_downloadsSection = 1` рядом с ними. Расходятся такие списки молча:
/// пятый раздел появился бы в обойме, но не в счёте, и клавиша вела бы
/// в пустоту.
enum AppSection {
  library,
  downloads,
  saves,
  settings;

  /// Раздел по номеру, с оглядкой на края: номер приходит и от клавиши, и
  /// от геймпада, и выйти за список он не должен.
  static AppSection at(int index) => values[index.clamp(0, values.length - 1)];

  /// Соседний раздел по кругу: обойма листается и вправо, и влево.
  AppSection shifted(int delta) {
    final next = (index + delta) % values.length;
    return values[next < 0 ? next + values.length : next];
  }
}
