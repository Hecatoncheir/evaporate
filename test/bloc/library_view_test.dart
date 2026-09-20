import 'package:evaporate/bloc/library_view/library_view_bloc.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/models/shelf.dart';
import 'package:flutter_test/flutter_test.dart';

/// Человек открывает библиотеку, чтобы продолжить, а не чтобы читать
/// список с начала: наверху то, что происходит прямо сейчас, за ним —
/// недавно запущенное, и лишь потом всё остальное по алфавиту.
void main() {
  Game game(
    String title, {
    GameStatus status = GameStatus.notInstalled,
    DateTime? lastPlayed,
  }) => Game(
    id: title,
    title: title,
    addedAt: DateTime(2026),
    status: status,
    lastPlayed: lastPlayed,
  );

  final now = DateTime(2026, 9, 20);

  final games = [
    game('Ярость', status: GameStatus.installed),
    game('Бездна', status: GameStatus.running),
    game(
      'Вектор',
      status: GameStatus.installed,
      lastPlayed: now.subtract(const Duration(hours: 1)),
    ),
    game('Астра', status: GameStatus.downloading),
    game('Омега'),
  ];

  List<String> titles(List<Game> list) => [for (final g in list) g.title];

  test('идущее сейчас стоит выше недавнего, а недавнее — выше остальных', () {
    expect(titles(searchGames(games, '')), [
      'Бездна',
      'Астра',
      'Вектор',
      'Ярость',
      'Омега',
    ]);
  });

  test('поиск не различает регистра и ищет вхождением', () {
    expect(titles(searchGames(games, 'ЕКТ')), ['Вектор']);
  });

  test('пустой запрос оставляет всё', () {
    expect(searchGames(games, '   '), hasLength(games.length));
  });

  // Числа у полок считаются по найденному: иначе «Все: 40» стояло бы рядом
  // с пустой сеткой.
  test('полка выбирается из найденного, а не из всей библиотеки', () {
    const view = LibraryView(query: 'а', shelf: Shelf.installed);

    expect(titles(view.found(games)), ['Бездна', 'Астра', 'Омега']);
    // Запущенная игра установлена по определению, качающаяся — ещё нет.
    expect(titles(view.shown(games)), ['Бездна']);
  });

  group('блок', () {
    test('набранное и выбранная полка доходят до состояния', () async {
      final bloc = LibraryViewBloc();
      addTearDown(bloc.close);

      bloc
        ..add(const LibraryQueryChanged('ведьмак'))
        ..add(const LibraryShelfSelected(Shelf.notInstalled));
      await bloc.stream.firstWhere((s) => s.shelf == Shelf.notInstalled);

      expect(bloc.state.query, 'ведьмак');
      expect(bloc.state.shelf, Shelf.notInstalled);
    });
  });
}
