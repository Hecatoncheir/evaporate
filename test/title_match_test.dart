import 'package:evaporate/models/game.dart';
import 'package:evaporate/services/saves/title_match.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final added = DateTime(2026);
  Game game(String id, String title) =>
      Game(id: id, title: title, addedAt: added);

  test('регистр и пробелы по краям названия не в счёт', () {
    expect(sameGameTitle('  Hades ', 'hades'), isTrue);
    expect(sameGameTitle('Hades', 'Hades II'), isFalse);
  });

  test('совпавшая по названию игра идёт первой, прочие не теряются', () {
    final games = [
      game('a', 'Celeste'),
      game('b', 'Hades'),
      game('c', 'Tunic'),
    ];

    final sorted = gamesMatchingFirst(games, 'HADES');

    expect(sorted.map((g) => g.id), ['b', 'a', 'c']);
  });
}
