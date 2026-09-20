import 'game.dart';

/// Вкладки поверх сетки. Раскладывают библиотеку без остатка: игра ровно в
/// одной из двух, и суммы сходятся с «Все».
enum Shelf { all, installed, notInstalled }

/// Игры, стоящие на полке.
///
/// Запущенная игра установлена по определению, качающаяся — ещё нет.
List<Game> gamesOnShelf(List<Game> games, Shelf shelf) => switch (shelf) {
  Shelf.all => games,
  Shelf.installed =>
    games
        .where(
          (g) =>
              g.status == GameStatus.installed ||
              g.status == GameStatus.running,
        )
        .toList(),
  Shelf.notInstalled =>
    games
        .where(
          (g) =>
              g.status != GameStatus.installed &&
              g.status != GameStatus.running,
        )
        .toList(),
};
