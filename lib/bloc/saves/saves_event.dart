part of 'saves_bloc.dart';

sealed class SavesEvent extends Equatable {
  const SavesEvent();

  @override
  List<Object?> get props => [];
}

/// Прочитать список снимков с диска при старте приложения.
final class SavesLoadRequested extends SavesEvent {
  const SavesLoadRequested();
}

/// Игра вышла из библиотеки — её снимки больше никому не нужны.
///
/// Приходит подпиской на библиотеку, а не вызовом: зависимость идёт в одну
/// сторону, сохранения знают библиотеку, а не наоборот.
final class GameSnapshotsDropped extends SavesEvent {
  const GameSnapshotsDropped(this.gameId);

  final String gameId;

  @override
  List<Object?> get props => [gameId];
}

final class SnapshotRequested extends SavesEvent {
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

final class SnapshotRestoreRequested extends SavesEvent {
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

final class SnapshotImportRequested extends SavesEvent {
  const SnapshotImportRequested({required this.path, required this.game});

  final String path;
  final Game game;

  @override
  List<Object?> get props => [path, game.id];
}

final class SnapshotExportRequested extends SavesEvent {
  const SnapshotExportRequested({
    required this.snapshot,
    required this.destination,
  });

  final SaveSnapshot snapshot;
  final String destination;

  @override
  List<Object?> get props => [snapshot.id, destination];
}

final class SnapshotDeleted extends SavesEvent {
  const SnapshotDeleted(this.snapshot);

  final SaveSnapshot snapshot;

  @override
  List<Object?> get props => [snapshot.id];
}

/// Посмотреть, что изменилось, пока игра работала.
///
/// Отдельным событием, а не внутри выхода из игры: обход папок занимает
/// секунды, а состояние после выхода должно обновиться сразу.
final class SaveHintsRequested extends SavesEvent {
  const SaveHintsRequested({required this.game, required this.since});

  final Game game;

  /// Момент запуска игры: всё, что изменилось позже, — след её работы.
  final DateTime since;

  @override
  List<Object?> get props => [game, since];
}

/// Принять найденные папки как правила.
final class SaveHintsAccepted extends SavesEvent {
  const SaveHintsAccepted({required this.game, required this.suggestions});

  final Game game;
  final List<SavePathSuggestion> suggestions;

  @override
  List<Object?> get props => [game, suggestions];
}

/// Убрать подсказки, ничего не приняв.
final class SaveHintsDismissed extends SavesEvent {
  const SaveHintsDismissed(this.gameId);

  final String gameId;

  @override
  List<Object?> get props => [gameId];
}

/// Снять сохранения всех настроенных игр и выгрузить их в одну папку.
final class BulkExportRequested extends SavesEvent {
  const BulkExportRequested(this.destinationDir);

  final String destinationDir;

  @override
  List<Object?> get props => [destinationDir];
}

/// Забрать все пакеты сохранений из папки и разложить по играм.
final class BulkImportRequested extends SavesEvent {
  const BulkImportRequested(this.sourceDir, {this.overwriteNewer = false});

  final String sourceDir;

  /// Восстанавливать и те игры, где сохранения на этом устройстве
  /// новее пакета. По умолчанию такие пропускаются: пакет с другого
  /// устройства может оказаться старым, а прогресс — уже не вернуть.
  final bool overwriteNewer;

  @override
  List<Object?> get props => [sourceDir, overwriteNewer];
}

final class SyncFolderScanRequested extends SavesEvent {
  const SyncFolderScanRequested();
}

/// Импорт пакета с другого устройства и немедленное восстановление —
/// путь «взял и играю дальше» одним событием.
final class SyncPackageApplied extends SavesEvent {
  const SyncPackageApplied({required this.path, required this.game});

  final String path;
  final Game game;

  @override
  List<Object?> get props => [path, game.id];
}

/// Снимок уже снят — записать его в состояние.
///
/// Внутреннее: снимок перед запуском игры снимается методом, потому что
/// библиотека обязана его дождаться, а в состояние он попадает как всё
/// остальное — событием.
final class SnapshotTaken extends SavesEvent {
  const SnapshotTaken(this.snapshot);

  final SaveSnapshot snapshot;

  @override
  List<Object?> get props => [snapshot];
}
