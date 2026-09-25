import '../data/game_facts.dart';
import '../data/sample_data.dart';
import '../widgets/ev_game_card.dart';
import '../widgets/ev_icon.dart';

/// Как показана библиотека. «Пульт» сюда не входит: он забирает весь
/// экран и живёт своим маршрутом.
enum EvLibraryView {
  showcase('Витрина', EvIcons.library),
  wall('Стена', EvIcons.wall),
  term('Терминал', EvIcons.rows);

  const EvLibraryView(this.label, this.icon);

  final String label;
  final String icon;
}

/// Фильтры «Стены».
enum EvWallFilter {
  all('Все'),
  ready('Установлены'),
  downloads('Качаются'),
  recent('Недавние');

  const EvWallFilter(this.label);

  final String label;

  /// Недавние — те, у кого есть время последней сессии: герой и полка
  /// «Продолжить». В прототипе список был написан рядом отдельно и держал
  /// «Грозовой фронт», которого на полке нет.
  List<SampleGame> of(List<SampleGame> games) => switch (this) {
    all => games,
    ready => [
      for (final g in games)
        if (g.state == EvGameState.ready) g,
    ],
    downloads => [
      for (final g in games)
        if (g.state != EvGameState.ready) g,
    ],
    recent => [
      for (final g in games)
        if (g.lastPlayed != null) g,
    ],
  };
}

/// Что делает главная кнопка у игры: играть, если она на диске, иначе —
/// в загрузки, где она уже качается или ждёт. В прототипе там стояло
/// «Скачать», хотя качать заново было нечего.
String evMainAction(SampleGame game) =>
    game.state == EvGameState.ready ? 'Играть' : 'К загрузкам';

/// Столбцы «Терминала», по которым можно сортировать.
enum EvTermSort {
  name('Название', text: true),
  genre('Жанр', text: true),
  size('Размер'),
  hours('Часы'),
  last('Последний запуск');

  const EvTermSort(this.label, {this.text = false});

  final String label;

  /// Текст начинает с «А», числа — с большего.
  final bool text;
}

/// Строка «Терминала»: всё из библиотеки и сведений об игре.
class EvTermRow {
  EvTermRow(this.game) : facts = EvGameFacts.of(game);

  final SampleGame game;
  final EvGameFacts facts;

  /// Версия без «v»; у дополнений её нет.
  String get version =>
      game.version.startsWith('v') ? game.version.substring(1) : '—';

  double get sizeGb => double.tryParse(game.size.split(' ').first) ?? 0;

  /// Чем больше, тем недавнее: недавние — в порядке библиотеки, она
  /// идёт от последней запущенной; дальше — по давности подписи;
  /// в конце — те, что не запускали.
  int get recency {
    if (game.lastPlayed != null) return 100 - sampleLibrary.indexOf(game);
    final older = EvGameFacts.olderAgo.indexOf(facts.lastAgo);
    return older < 0 ? 0 : EvGameFacts.olderAgo.length - older;
  }

  Comparable<Object> key(EvTermSort sort) => switch (sort) {
    EvTermSort.name => game.title,
    EvTermSort.genre => game.genre,
    EvTermSort.size => sizeGb,
    EvTermSort.hours => facts.hours,
    EvTermSort.last => recency,
  };
}

/// Строки по столбцу. [ascending] — от «А» и от меньшего.
List<EvTermRow> evTermRows(
  List<SampleGame> games,
  EvTermSort sort, {
  required bool ascending,
}) {
  final rows = [for (final g in games) EvTermRow(g)];
  // Сортировка устойчивая: равные остаются в порядке библиотеки.
  final order = {for (final (i, r) in rows.indexed) r: i};
  rows.sort((a, b) {
    final c = a.key(sort).compareTo(b.key(sort));
    if (c != 0) return ascending ? c : -c;
    return order[a]!.compareTo(order[b]!);
  });
  return rows;
}
