part of 'navigation_bloc.dart';

class NavigationState extends Equatable {
  const NavigationState({
    this.section = AppSection.library,
    this.selectedGameId,
    this.openedGameId,
    this.searchFocusSeq = 0,
  });

  final AppSection section;

  /// Игра под курсором в сетке. Кнопка «Играть» работает по ней, не заходя
  /// на страницу игры.
  final String? selectedGameId;

  /// Игра, чья страница открыта поверх сетки. Ничего не открыто — `null`.
  final String? openedGameId;

  /// Сколько раз просили увести фокус в поиск.
  ///
  /// Фокус — ресурс, и в состоянии ему не место: здесь лежит только
  /// просьба. Счётчик, а не флаг, по той же причине, что и у `Notice.seq`:
  /// две просьбы подряд иначе считались бы одним состоянием, и вторая
  /// пропала бы.
  final int searchFocusSeq;

  NavigationState copyWith({
    AppSection? section,
    Object? selectedGameId = _unset,
    Object? openedGameId = _unset,
    int? searchFocusSeq,
  }) {
    return NavigationState(
      section: section ?? this.section,
      selectedGameId: selectedGameId == _unset
          ? this.selectedGameId
          : selectedGameId as String?,
      openedGameId: openedGameId == _unset
          ? this.openedGameId
          : openedGameId as String?,
      searchFocusSeq: searchFocusSeq ?? this.searchFocusSeq,
    );
  }

  @override
  List<Object?> get props => [
    section,
    selectedGameId,
    openedGameId,
    searchFocusSeq,
  ];

  static const _unset = Object();
}
