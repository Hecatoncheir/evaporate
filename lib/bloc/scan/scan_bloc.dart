import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/launch/library_scanner.dart';
import '../../services/launch/scan_session.dart';
import '../frequent_event.dart';

part 'scan_event.dart';
part 'scan_state.dart';

/// Поиск установленных игр: ход обхода и что человек из найденного отметил.
///
/// Блок, а не состояние окна: `ScanSession` — внешний источник, такой же,
/// как движок загрузок, и находки приходят из него сами, пока человек
/// смотрит. Отбор при этом его, человека, и переживать приход новой
/// находки он обязан.
class ScanBloc extends Bloc<ScanEvent, ScanState> {
  ScanBloc(this.session) : super(const ScanState()) {
    on<ScanSessionChanged>(_onSessionChanged);
    on<ScanNarrowed>(_onNarrowed);
    on<ScanFolderDropped>(_onDropped);
    on<ScanStopRequested>((event, emit) => session.stop());
    on<ScanGameToggled>(_onToggled);
    session.addListener(_pushSession);
    add(const ScanSessionChanged());
  }

  final ScanSession session;

  void _pushSession() => add(const ScanSessionChanged());

  void _onSessionChanged(ScanSessionChanged event, Emitter<ScanState> emit) {
    emit(
      state.copyWith(
        found: session.found,
        running: session.isRunning,
        complete: session.isComplete,
      ),
    );
  }

  /// Сужает поиск до одной папки, отменяя начатое.
  Future<void> _onNarrowed(ScanNarrowed event, Emitter<ScanState> emit) {
    emit(state.copyWith(wrongDrop: false));
    return session.scanOnly(event.directory);
  }

  /// Бросили что-то в окно: папку берём, остальное — отказ словами.
  ///
  /// Молчаливый отказ хуже всего: человек не поймёт, случилось
  /// что-нибудь или нет.
  Future<void> _onDropped(
    ScanFolderDropped event,
    Emitter<ScanState> emit,
  ) async {
    for (final path in event.paths) {
      if (await Directory(path).exists()) {
        emit(state.copyWith(wrongDrop: false));
        await session.scanOnly(path);
        return;
      }
    }
    emit(state.copyWith(wrongDrop: true));
  }

  /// Уверенно найденные игры отмечены сразу, поэтому запоминаем две
  /// половины: снятое с уверенных и поставленное на сомнительных.
  ///
  /// Запоминать надо именно их, а не сам набор отмеченного: находки
  /// приходят по ходу поиска, и новая воскрешала бы снятые галочки.
  void _onToggled(ScanGameToggled event, Emitter<ScanState> emit) {
    final dir = event.game.installDir;
    final unchecked = Set<String>.from(state.unchecked);
    final checked = Set<String>.from(state.checked);
    if (event.game.confident) {
      event.selected ? unchecked.remove(dir) : unchecked.add(dir);
    } else {
      event.selected ? checked.add(dir) : checked.remove(dir);
    }
    emit(state.copyWith(unchecked: unchecked, checked: checked));
  }

  @override
  Future<void> close() {
    session.removeListener(_pushSession);
    return super.close();
  }
}
