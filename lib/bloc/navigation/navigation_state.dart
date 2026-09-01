part of 'navigation_bloc.dart';

class NavigationState extends Equatable {
  const NavigationState({this.section = 0, this.selectedGameId});

  final int section;
  final String? selectedGameId;

  NavigationState copyWith({int? section, Object? selectedGameId = _unset}) {
    return NavigationState(
      section: section ?? this.section,
      selectedGameId: selectedGameId == _unset
          ? this.selectedGameId
          : selectedGameId as String?,
    );
  }

  @override
  List<Object?> get props => [section, selectedGameId];

  static const _unset = Object();
}
