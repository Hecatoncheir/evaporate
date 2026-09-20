part of 'downloads_bloc.dart';

/// События сравниваются **по тому, о чём они**, а не по всему содержимому:
/// в `props` идут `game.id` и `snapshot.id`, а не сами объекты. Иначе
/// сравнение свелось бы к тождеству ссылок — ни `Game`, ни `SaveSnapshot`
/// не `Equatable`, — и «то же событие о той же игре» никогда не совпало бы
/// само с собой. Ничего, кроме тестов, события здесь не сравнивает, и
/// трансформеры, которым равенство важно (`droppable`, `restartable`), не
/// используются.
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
  const DownloadCancelRequested(this.game, {this.deleteFiles = false});

  final Game game;

  /// Убрать заодно и скачанное. По умолчанию нет: снятая задача оставляет
  /// файлы на диске, и человек вправе к ним вернуться.
  final bool deleteFiles;

  @override
  List<Object?> get props => [game.id, deleteFiles];
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
  const DownloadReordered({required this.id, this.beforeId});

  final String id;

  /// Перед какой задачей встать. `null` — в конец очереди.
  ///
  /// Сосед, а не номер: номер у движка свой, в общем порядке всех задач, и
  /// считать его из виджета значило бы знать там устройство движка.
  final String? beforeId;

  @override
  List<Object?> get props => [id, beforeId];
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
