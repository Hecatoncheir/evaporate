part of 'download_history_bloc.dart';

sealed class DownloadHistoryEvent extends Equatable {
  const DownloadHistoryEvent();

  @override
  List<Object?> get props => [];
}

/// Движок прислал новое состояние задачи.
///
/// Прошлое состояние идёт вместе с новым: выборку добавляют, только когда
/// что-то и правда сдвинулось, а прошлое знает тот, кто держит задачу.
final class SpeedSampled extends DownloadHistoryEvent {
  const SpeedSampled({required this.task, required this.previous});

  final DownloadTask task;
  final DownloadTask previous;

  @override
  List<Object?> get props => [task, previous];
}
