part of 'library_bloc.dart';

sealed class LibraryEvent extends Equatable {
  const LibraryEvent();

  @override
  List<Object?> get props => [];
}

final class LibraryLoadRequested extends LibraryEvent {
  const LibraryLoadRequested();
}

/// Идентификатор генерирует вызывающая сторона: диалогу добавления нужно
/// сразу знать, какую игру выделять, а событие ничего не возвращает.
final class GameAdded extends LibraryEvent {
  const GameAdded({
    required this.id,
    required this.title,
    this.source,
    this.installDir,
    this.executablePath,
    this.status = GameStatus.notInstalled,
  });

  final String id;
  final String title;
  final GameSource? source;
  final String? installDir;
  final String? executablePath;
  final GameStatus status;

  @override
  List<Object?> get props => [
    id,
    title,
    source,
    installDir,
    executablePath,
    status,
  ];
}

final class GameUpdated extends LibraryEvent {
  const GameUpdated(this.game);

  final Game game;

  @override
  List<Object?> get props => [game.id, game.status, game.saveProfile.rules];
}

final class GameRemoved extends LibraryEvent {
  const GameRemoved(this.game, {this.deleteFiles = false});

  final Game game;
  final bool deleteFiles;

  @override
  List<Object?> get props => [game.id, deleteFiles];
}

final class GameLaunchRequested extends LibraryEvent {
  const GameLaunchRequested(this.game);

  final Game game;

  @override
  List<Object?> get props => [game.id];
}

final class GameStopRequested extends LibraryEvent {
  const GameStopRequested(this.game);

  final Game game;

  @override
  List<Object?> get props => [game.id];
}

/// Процесс игры завершился. Событие приходит из колбэка лаунчера — это тот
/// случай, ради которого события удобнее методов: внешний источник просто
/// кладёт факт в очередь, а блок решает, что с ним делать.
final class GameExited extends LibraryEvent {
  const GameExited({
    required this.gameId,
    required this.played,
    required this.exitCode,
  });

  final String gameId;
  final Duration played;
  final int exitCode;

  @override
  List<Object?> get props => [gameId, played, exitCode];
}

/// Набор запущенных игр изменился (из лаунчера).
final class RunningGamesChanged extends LibraryEvent {
  const RunningGamesChanged(this.ids);

  final Set<String> ids;

  @override
  List<Object?> get props => [ids];
}

final class SnapshotRequested extends LibraryEvent {
  const SnapshotRequested(
    this.game, {
    this.origin = SnapshotOrigin.manual,
    this.note,
  });

  final Game game;
  final SnapshotOrigin origin;
  final String? note;

  @override
  List<Object?> get props => [game.id, origin, note];
}

final class SnapshotRestoreRequested extends LibraryEvent {
  const SnapshotRestoreRequested({
    required this.game,
    required this.snapshot,
    this.backupCurrent = true,
    this.wipeTarget = false,
  });

  final Game game;
  final SaveSnapshot snapshot;
  final bool backupCurrent;
  final bool wipeTarget;

  @override
  List<Object?> get props => [game.id, snapshot.id, backupCurrent, wipeTarget];
}

final class SnapshotImportRequested extends LibraryEvent {
  const SnapshotImportRequested({required this.path, required this.game});

  final String path;
  final Game game;

  @override
  List<Object?> get props => [path, game.id];
}

final class SnapshotExportRequested extends LibraryEvent {
  const SnapshotExportRequested({
    required this.snapshot,
    required this.destination,
  });

  final SaveSnapshot snapshot;
  final String destination;

  @override
  List<Object?> get props => [snapshot.id, destination];
}

final class SnapshotDeleted extends LibraryEvent {
  const SnapshotDeleted(this.snapshot);

  final SaveSnapshot snapshot;

  @override
  List<Object?> get props => [snapshot.id];
}

final class SyncFolderScanRequested extends LibraryEvent {
  const SyncFolderScanRequested();
}

/// Импорт пакета с другого устройства и немедленное восстановление —
/// путь «взял и играю дальше» одним событием.
final class SyncPackageApplied extends LibraryEvent {
  const SyncPackageApplied({required this.path, required this.game});

  final String path;
  final Game game;

  @override
  List<Object?> get props => [path, game.id];
}
