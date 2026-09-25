import 'game.dart';

/// Вкладки поверх сетки.
///
/// «Установленные» и «Не установленные» раскладывают библиотеку без
/// остатка: игра ровно в одной из двух, и суммы сходятся с «Все».
/// «Продолжить» — не третья часть, а выборка: игры, в которые уже
/// играли, свежие сверху. Она пересекается с остальными намеренно —
/// вернуться к недавней игре хотят, не вспоминая, установлена ли она.
enum Shelf { all, recent, installed, notInstalled }

/// Игры, стоящие на полке.
///
/// Запущенная игра установлена по определению, качающаяся — ещё нет.
List<Game> gamesOnShelf(List<Game> games, Shelf shelf) => switch (shelf) {
  Shelf.all => games,
  Shelf.recent => _recent(games),
  Shelf.installed => games.where(_installed).toList(),
  Shelf.notInstalled => games.where((g) => !_installed(g)).toList(),
};

bool _installed(Game game) =>
    game.status == GameStatus.installed || game.status == GameStatus.running;

/// Сыгранные, от последнего запуска к давнему.
List<Game> _recent(List<Game> games) {
  final played = [
    for (final game in games)
      if (game.play.lastPlayed != null) game,
  ];
  return played
    ..sort((a, b) => b.play.lastPlayed!.compareTo(a.play.lastPlayed!));
}
