part of 'download_history_bloc.dart';

sealed class DownloadHistoryEvent extends Equatable {
  const DownloadHistoryEvent();

  @override
  List<Object?> get props => [];
}

/// Движок прислал снимок задач — выборка по каждой.
///
/// Выборка добавляется всегда, а не только когда что-то сдвинулось: у
/// замершей загрузки график обязан ползти нулями, а не стоять на последней
/// живой скорости, как будто качается.
final class TasksSampled extends DownloadHistoryEvent implements FrequentEvent {
  const TasksSampled(this.tasks);

  final List<DownloadTask> tasks;

  @override
  List<Object?> get props => [tasks];
}
