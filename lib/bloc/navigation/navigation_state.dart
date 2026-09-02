part of 'navigation_bloc.dart';

class NavigationState extends Equatable {
  const NavigationState({
    this.section = 0,
    this.selectedGameId,
    this.openedGameId,
  });

  final int section;

  /// Игра под курсором в сетке. Кнопка «Играть» работает по ней, не заходя
  /// на страницу игры.
  final String? selectedGameId;

  /// Игра, чья страница открыта поверх сетки. Ничего не открыто — `null`.
  final String? openedGameId;

  NavigationState copyWith({
    int? section,
    Object? selectedGameId = _unset,
    Object? openedGameId = _unset,
  }) {
    return NavigationState(
      section: section ?? this.section,
      selectedGameId: selectedGameId == _unset
          ? this.selectedGameId
          : selectedGameId as String?,
      openedGameId: openedGameId == _unset
          ? this.openedGameId
          : openedGameId as String?,
    );
  }

  @override
  List<Object?> get props => [section, selectedGameId, openedGameId];

  static const _unset = Object();
}
