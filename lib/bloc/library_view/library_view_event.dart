part of 'library_view_bloc.dart';

sealed class LibraryViewEvent extends Equatable {
  const LibraryViewEvent();

  @override
  List<Object?> get props => [];
}

/// В строке поиска набрали новое.
final class LibraryQueryChanged extends LibraryViewEvent {
  const LibraryQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// Выбрали полку.
final class LibraryShelfSelected extends LibraryViewEvent {
  const LibraryShelfSelected(this.shelf);

  final Shelf shelf;

  @override
  List<Object?> get props => [shelf];
}
