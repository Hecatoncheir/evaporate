part of 'library_view_bloc.dart';

/// Запрос и полка.
class LibraryView extends Equatable {
  const LibraryView({this.query = '', this.shelf = Shelf.all});

  final String query;
  final Shelf shelf;

  LibraryView copyWith({String? query, Shelf? shelf}) =>
      LibraryView(query: query ?? this.query, shelf: shelf ?? this.shelf);

  /// Что показать из [games]: сперва отбор поиском, потом полка.
  ///
  /// Порядок важен: числа у полок считаются по найденному, иначе «Все: 40»
  /// стояло бы рядом с пустой сеткой.
  List<Game> found(List<Game> games) => searchGames(games, query);

  List<Game> shown(List<Game> games) => gamesOnShelf(found(games), shelf);

  @override
  List<Object?> get props => [query, shelf];
}
