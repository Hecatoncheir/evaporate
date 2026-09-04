part of 'downloads_bloc.dart';

sealed class DownloadsEvent extends Equatable {
  const DownloadsEvent();

  @override
  List<Object?> get props => [];
}

final class DownloadEngineStartRequested extends DownloadsEvent {
  const DownloadEngineStartRequested();
}

final class DownloadEngineRestartRequested extends DownloadsEvent {
  const DownloadEngineRestartRequested();
}

/// Применить настройки к демону (папка загрузок, лимиты) с перезапуском.
final class DownloadSettingsApplied extends DownloadsEvent {
  const DownloadSettingsApplied(this.settings);

  final AppSettings settings;

  @override
  List<Object?> get props => [settings];
}

/// Пересчитать ограничения: сменились настройки или запустилась игра.
final class DownloadLimitsRefreshed extends DownloadsEvent {
  const DownloadLimitsRefreshed();
}

final class DownloadRequested extends DownloadsEvent {
  const DownloadRequested({required this.game, required this.source});

  final Game game;
  final GameSource source;

  @override
  List<Object?> get props => [game.id, source.kind, source.value];
}

final class DownloadPauseRequested extends DownloadsEvent {
  const DownloadPauseRequested(this.game);

  final Game game;

  @override
  List<Object?> get props => [game.id];
}

final class DownloadResumeRequested extends DownloadsEvent {
  const DownloadResumeRequested(this.game);

  final Game game;

  @override
  List<Object?> get props => [game.id];
}

final class DownloadCancelRequested extends DownloadsEvent {
  const DownloadCancelRequested(this.game);

  final Game game;

  @override
  List<Object?> get props => [game.id];
}

/// Сохранить `.torrent` игры туда, куда указал пользователь.
final class TorrentExportRequested extends DownloadsEvent {
  const TorrentExportRequested({required this.game, required this.destination});

  final Game game;
  final String destination;

  @override
  List<Object?> get props => [game.id, destination];
}

/// Пользователь перетащил задачу в очереди.
final class DownloadReordered extends DownloadsEvent {
  const DownloadReordered({required this.id, required this.newIndex});

  final String id;
  final int newIndex;

  @override
  List<Object?> get props => [id, newIndex];
}

/// Движок прислал новый снимок задач. Событие приходит из его потока —
/// раз в секунду, пока идёт хотя бы одна загрузка.
final class EngineTasksChanged extends DownloadsEvent {
  const EngineTasksChanged(this.tasks);

  final List<DownloadTask> tasks;

  @override
  List<Object?> get props => [tasks];
}

final class EngineStatusChanged extends DownloadsEvent {
  const EngineStatusChanged(this.status);

  final EngineStatus status;

  @override
  List<Object?> get props => [status];
}

final class EngineStatsChanged extends DownloadsEvent {
  const EngineStatsChanged(this.stats);

  final EngineStats stats;

  @override
  List<Object?> get props => [stats];
}
