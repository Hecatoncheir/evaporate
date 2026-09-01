part of 'navigation_bloc.dart';

sealed class NavigationEvent extends Equatable {
  const NavigationEvent();

  @override
  List<Object?> get props => [];
}

/// Перейти к разделу по индексу (клик по рейлу).
final class SectionSelected extends NavigationEvent {
  const SectionSelected(this.index);

  final int index;

  @override
  List<Object?> get props => [index];
}

/// Следующий/предыдущий раздел по кругу (бамперы геймпада, Ctrl+Tab).
final class SectionCycled extends NavigationEvent {
  const SectionCycled(this.delta);

  final int delta;

  @override
  List<Object?> get props => [delta];
}

final class GameSelected extends NavigationEvent {
  const GameSelected(this.gameId);

  final String? gameId;

  @override
  List<Object?> get props => [gameId];
}

/// Уйти в поиск: раздел «Библиотека» плюс фокус в поле.
final class SearchFocusRequested extends NavigationEvent {
  const SearchFocusRequested();
}
