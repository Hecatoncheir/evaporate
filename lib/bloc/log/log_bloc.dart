import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/system/app_log.dart';

part 'log_event.dart';
part 'log_state.dart';

/// Журнал приложения на экране настроек.
///
/// Блок, а не состояние карточки: чтение идёт с диска и умеет не смочь, а
/// виджету не положено ни держать асинхронность, ни ловить её ошибки.
/// Побочная выгода — проверять показ журнала можно без `runAsync`: подменяют
/// сам `AppLog`.
class LogBloc extends Bloc<LogEvent, LogState> {
  LogBloc({AppLog? log})
    : _log = log ?? AppLog.instance,
      super(const LogState()) {
    on<LogShowRequested>(_onShow);
    on<LogClearRequested>(_onClear);
  }

  final AppLog _log;

  Future<void> _onShow(LogShowRequested event, Emitter<LogState> emit) async {
    if (state.busy) return;
    emit(state.copyWith(busy: true));
    // Записанное могло ещё не лечь на диск: пишем в очередь, а не сразу.
    await _log.flush();
    emit(state.copyWith(lines: await _log.tail(), busy: false));
  }

  Future<void> _onClear(LogClearRequested event, Emitter<LogState> emit) async {
    await _log.clear();
    emit(state.copyWith(lines: const []));
  }
}
