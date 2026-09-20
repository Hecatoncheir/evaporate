import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/game.dart';
import '../../models/shelf.dart';

part 'library_view_event.dart';
part 'library_view_query.dart';
part 'library_view_state.dart';

/// Как человек смотрит на библиотеку: что ищет и какую полку выбрал.
///
/// Свой блок экрана, а не поле в `LibraryState`: завелась бы там запись на
/// каждую игру ради строки поиска одного раздела? Нет — значит, и месту
/// этому там нет. В `State` страницы остаются наведение, фокус и прокрутка:
/// это не состояние, а ресурсы.
///
/// Задержки на набор здесь намеренно нет. Отбор и сортировка полусотни игр
/// стоят доли миллисекунды, а таймер в этом месте пришлось бы пережидать
/// в каждом виджет-тесте, который что-нибудь ищет.
class LibraryViewBloc extends Bloc<LibraryViewEvent, LibraryView> {
  LibraryViewBloc() : super(const LibraryView()) {
    on<LibraryQueryChanged>(
      (event, emit) => emit(state.copyWith(query: event.query)),
    );
    on<LibraryShelfSelected>(
      (event, emit) => emit(state.copyWith(shelf: event.shelf)),
    );
  }
}
