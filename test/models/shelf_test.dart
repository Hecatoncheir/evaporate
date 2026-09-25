import 'package:evaporate/models/game.dart';
import 'package:evaporate/models/shelf.dart';
import 'package:flutter_test/flutter_test.dart';

/// Полки над сеткой: две делят библиотеку, «Продолжить» — выборка.
void main() {
  final added = DateTime.utc(2026);
  Game game(String title, {GameStatus? status, DateTime? lastPlayed}) => Game(
    id: title,
    title: title,
    addedAt: added,
    status: status ?? GameStatus.notInstalled,
    play: PlayStats(lastPlayed: lastPlayed),
  );

  final library = [
    game('Давняя', status: GameStatus.installed, lastPlayed: DateTime(2026, 1)),
    game('Несыгранная', status: GameStatus.installed),
    game('Свежая', lastPlayed: DateTime(2026, 9, 20)),
    game('Идущая', status: GameStatus.running, lastPlayed: DateTime(2026, 5)),
  ];

  List<String> titles(Shelf shelf) => [
    for (final g in gamesOnShelf(library, shelf)) g.title,
  ];

  // Вернуться хотят к тому, что запускали последним: полка идёт от
  // свежего к давнему, а не в порядке добавления.
  test('«Продолжить» — сыгранные, от последнего запуска к давнему', () {
    expect(titles(Shelf.recent), ['Свежая', 'Идущая', 'Давняя']);
  });

  test('установленные и неустановленные делят библиотеку без остатка', () {
    final installed = titles(Shelf.installed);
    final rest = titles(Shelf.notInstalled);

    expect(installed, ['Давняя', 'Несыгранная', 'Идущая']);
    expect({...installed, ...rest}, {...titles(Shelf.all)});
    expect(installed.toSet().intersection(rest.toSet()), isEmpty);
  });

  // Выборка, а не часть: недавняя игра стоит и на своей полке по
  // установке — к ней возвращаются, не вспоминая, установлена ли она.
  test('«Продолжить» пересекается с полками установки', () {
    expect(titles(Shelf.recent), contains('Свежая'));
    expect(titles(Shelf.notInstalled), contains('Свежая'));
  });
}
