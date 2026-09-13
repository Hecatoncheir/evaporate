import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/game.dart';
import '../services/saves/save_manager.dart';
import '../services/system/app_log.dart';

/// Когда здешние сохранения игры менялись в последний раз.
///
/// Состояний три, и их обязано быть три. «Не знаем» и «сохранений здесь
/// никогда не было» — разные вещи: первое молчит, второе утверждает. Раньше
/// диалог их путал и на неудавшемся чтении заявлял, что сейвы никогда не
/// менялись, — то есть говорил неправду ровно там, где человек решает,
/// затирать ему свой прогресс или нет.
class SaveFreshness extends Equatable {
  const SaveFreshness.unknown() : known = false, changedAt = null;
  const SaveFreshness.read(this.changedAt) : known = true;

  /// Диск прочитан. Пока нет — строку не показывают вовсе.
  final bool known;

  /// `null` при [known] означает, что сохранений ещё не было.
  final DateTime? changedAt;

  @override
  List<Object?> get props => [known, changedAt];
}

/// Cubit, а не поле в `LibraryState` и не событие блока.
///
/// Лежит в `lib/bloc`, рядом с `notice.dart`, а не подле диалога: он пишет
/// в журнал по-русски, а `lib/ui` для русских литералов закрыт — и закрыт
/// правильно, потому что оттуда строки идут человеку на экран, а отсюда —
/// в файл.
///
/// Значение живёт ровно столько, сколько открыт диалог восстановления, и
/// нужно ему одному. В общем состоянии библиотеки оно копилось бы записью
/// на каждую игру ради одной строки в модальном окне — а `LibraryState` и
/// без того носит полтора десятка полей.
///
/// Событий у этой работы нет: её никто не подаёт извне, её просто делают
/// один раз при открытии. Там, где событие ничего не добавляет, Cubit —
/// тот же блок без обряда.
class SaveFreshnessCubit extends Cubit<SaveFreshness> {
  SaveFreshnessCubit(this._saves) : super(const SaveFreshness.unknown());

  final SaveManager _saves;

  /// Читает диск и кладёт ответ в состояние.
  ///
  /// Неудача оставляет «не знаем»: обход папок мог упереться в права, и
  /// выдавать это за «сейвов не было» нельзя.
  Future<void> read(Game game) async {
    try {
      final when = await _saves.lastLocalChange(game);
      if (!isClosed) emit(SaveFreshness.read(when));
    } on Object catch (error) {
      AppLog.instance.write('время правки сейвов «${game.title}»', error);
    }
  }
}
