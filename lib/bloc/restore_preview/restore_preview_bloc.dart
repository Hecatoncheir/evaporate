import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/game.dart';
import '../../models/save_snapshot.dart';
import '../../services/saves/bulk_transfer.dart';
import '../../services/saves/save_manager.dart';
import '../../services/system/app_log.dart';

part 'restore_preview_event.dart';
part 'restore_preview_state.dart';

/// Что человек узнаёт до того, как нажать «Восстановить»: куда лягут файлы
/// и не новее ли здешние сохранения самого снимка.
///
/// Живёт ровно столько, сколько открыт диалог, и нужен ему одному — но
/// блок, а не Cubit: чтение диска асинхронно и умеет не смочь, а «что
/// случилось → что изменилось» у такой работы должно быть видно в журнале.
///
/// Лежит в `lib/bloc`, а не подле диалога: он пишет в журнал по-русски, а
/// `lib/ui` для русских литералов закрыт — и закрыт правильно, потому что
/// оттуда строки идут человеку на экран, а отсюда в файл.
class RestorePreviewBloc extends Bloc<RestorePreviewEvent, RestorePreview> {
  RestorePreviewBloc(this._saves) : super(const RestorePreview()) {
    on<RestorePreviewRequested>(_onRequested);
  }

  final SaveManager _saves;

  /// Допуск тот же, что и у массового переноса: часы разных устройств
  /// расходятся, а время изменения файла хранится с разной точностью на
  /// разных файловых системах.
  static const conflictTolerance = BulkTransfer.defaultConflictTolerance;

  Future<void> _onRequested(
    RestorePreviewRequested event,
    Emitter<RestorePreview> emit,
  ) async {
    // Цели считает менеджер, а не диалог: раскладывать файлы будет он, и
    // обещать здесь что-то своё значит обещать не то.
    emit(
      state.copyWith(
        targets: _saves.previewTargets(event.game, event.snapshot),
      ),
    );

    final DateTime? when;
    try {
      when = await _saves.lastLocalChange(event.game);
    } on Object catch (error) {
      // Обход папок мог упереться в права. Выдавать это за «сейвов не
      // было» нельзя: человек решает, затирать ли свой прогресс.
      AppLog.instance.write('время правки сейвов «${event.game.title}»', error);
      return;
    }

    emit(
      state.copyWith(
        known: true,
        changedAt: when,
        newer:
            when != null &&
            when.isAfter(event.snapshot.createdAt.add(conflictTolerance)),
      ),
    );
  }
}
