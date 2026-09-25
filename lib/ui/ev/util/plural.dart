/// Согласование с числом: 1 игра, 2 игры, 5 игр, 11 игр, 21 игра.
String ruPlural(int n, String one, String few, String many) {
  final mod10 = n.abs() % 10, mod100 = n.abs() % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}

/// «193 дня», «392 часа» — числительное вместе с числом.
String ruCount(int n, String one, String few, String many) =>
    '$n ${ruPlural(n, one, few, many)}';
