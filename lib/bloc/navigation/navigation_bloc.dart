import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/app_section.dart';
import '../library/library_bloc.dart';

part 'navigation_event.dart';
part 'navigation_state.dart';

/// Раздел и выбранная игра. Геймпаду нужно дотянуться до них снаружи:
/// кнопка «Играть» нажимается независимо от того, какой виджет в фокусе.
class NavigationBloc extends Bloc<NavigationEvent, NavigationState> {
  NavigationBloc({LibraryBloc? library}) : super(const NavigationState()) {
    // Игру, брошенную в окно библиотеки, подсвечиваем: иначе она затеряется
    // среди прочих. Библиотека об этом не знает — она лишь сообщает, что у
    // неё завелось.
    _drops = library?.gameDrops.listen((dropped) {
      if (!dropped.select || dropped.games.isEmpty) return;
      add(GameSelected(dropped.games.last.id));
    });

    on<SectionSelected>((event, emit) {
      emit(state.copyWith(section: event.section));
    });

    on<SectionCycled>((event, emit) {
      emit(state.copyWith(section: state.section.shifted(event.delta)));
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
      // Сам фокус ставит библиотека: он ресурс, и блоку не принадлежит.
      emit(
        state.copyWith(
          section: AppSection.library,
          openedGameId: null,
          searchFocusSeq: state.searchFocusSeq + 1,
        ),
      );
    });
  }

  StreamSubscription<DroppedGames>? _drops;

  /// Закрывает страницу игры, если она открыта. Возвращает `true`, когда
  /// закрывать было что: кнопке «назад» этого достаточно, чтобы не идти
  /// дальше и не сбрасывать заодно фокус.
  // Событие ничего не возвращает, а «было что закрывать» — это ответ, по
  // которому вызывающий решает, идти ли дальше.
  // ignore: avoid_public_bloc_methods
  bool closeOpenedGame() {
    if (state.section != AppSection.library || state.openedGameId == null) {
      return false;
    }
    add(const GameOpened(null));
    return true;
  }

  @override
  Future<void> close() async {
    await _drops?.cancel();
    return super.close();
  }
}
