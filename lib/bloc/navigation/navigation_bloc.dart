import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'navigation_event.dart';
part 'navigation_state.dart';

/// Раздел и выбранная игра. Геймпаду нужно дотянуться до них снаружи:
/// кнопка «Играть» нажимается независимо от того, какой виджет в фокусе.
class NavigationBloc extends Bloc<NavigationEvent, NavigationState> {
  NavigationBloc() : super(const NavigationState()) {
    on<SectionSelected>((event, emit) {
      emit(state.copyWith(section: event.index.clamp(0, sectionCount - 1)));
    });

    on<SectionCycled>((event, emit) {
      final next = (state.section + event.delta) % sectionCount;
      emit(state.copyWith(section: next < 0 ? next + sectionCount : next));
    });

    on<GameSelected>((event, emit) {
      emit(state.copyWith(selectedGameId: event.gameId));
    });

    on<GameOpened>((event, emit) {
      // Открытая игра всегда и выбранная: закрыв её страницу, курсор в
      // сетке должен оказаться на ней же.
      emit(
        state.copyWith(
          openedGameId: event.gameId,
          selectedGameId: event.gameId ?? state.selectedGameId,
        ),
      );
    });

    on<SearchFocusRequested>((event, emit) {
      // Поиск живёт над сеткой — страница игры его закрывает собой.
      emit(state.copyWith(section: 0, openedGameId: null));
      // Фокус — не состояние, а ресурс: его нельзя положить в state,
      // поэтому запрашиваем прямо здесь.
      searchFocus.requestFocus();
    });
  }

  static const sectionCount = 4;

  /// Закрывает страницу игры, если она открыта. Возвращает `true`, когда
  /// закрывать было что: кнопке «назад» этого достаточно, чтобы не идти
  /// дальше и не сбрасывать заодно фокус.
  bool closeOpenedGame() {
    if (state.section != 0 || state.openedGameId == null) return false;
    add(const GameOpened(null));
    return true;
  }

  /// Фокус поля поиска.
  final FocusNode searchFocus = FocusNode(debugLabel: 'search');

  @override
  Future<void> close() {
    searchFocus.dispose();
    return super.close();
  }
}
