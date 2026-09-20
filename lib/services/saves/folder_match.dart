/// Насколько имя папки похоже на название игры.
///
/// Мерка одна на двоих, и это важнее краткости: по ней ищет папки
/// `SavePathFinder`, по ней же отбирает изменившееся за сеанс
/// `SaveActivityWatch`. Разойдись копии — поиск по названию и подсказка
/// после выхода из игры сказали бы об одной и той же папке разное, а
/// человек по ним решает, где лежат его сохранения.
///
/// С `sameGameTitle` из `title_match.dart` это разные вещи: там сверяют
/// два названия игры, здесь — догадка по имени папки, которое игра
/// придумывала себе сама.
class FolderMatch {
  const FolderMatch._();

  /// Приводит к сравнимому виду: строчные буквы, без знаков, одиночные
  /// пробелы.
  ///
  /// Знаки именно **убираются** (`Half-Life` → `halflife`), а не заменяются
  /// пробелом, как в `ReleaseName`: тому нужны слова, а папку игра чаще
  /// называет слитно.
  static String normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-zа-я0-9\s]', unicode: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Очки совпадения: точное, вхождение, по словам. Ноль — не похоже.
  ///
  /// Обе строки ожидаются уже приведёнными [normalize]: по сырым считать
  /// нечего — `Half-Life` и `half life` разошлись бы.
  static int score(String candidate, String needle) {
    if (candidate.isEmpty || needle.isEmpty) return 0;
    if (candidate == needle) return 100;
    if (candidate.contains(needle) || needle.contains(candidate)) {
      final shorter = candidate.length < needle.length ? candidate : needle;
      // Совпадения по двум-трём буквам ничего не значат.
      return shorter.length >= 4 ? 70 : 0;
    }

    final words = needle
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3)
        .toList();
    if (words.isEmpty) return 0;
    final matched = words.where(candidate.contains).length;
    if (matched == words.length) return 55;
    if (matched > 0 && words.length > 1) return 30;
    return 0;
  }
}
