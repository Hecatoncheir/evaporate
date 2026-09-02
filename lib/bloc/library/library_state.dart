part of 'library_bloc.dart';

class LibraryState extends Equatable {
  const LibraryState({
    this.games = const [],
    this.snapshots = const {},
    this.runningIds = const {},
    this.busy = const {},
    this.loaded = false,
    this.notice,
    this.syncPackages = const [],
    this.scanningSync = false,
    this.syncScanned = false,
    this.bulkReport,
    this.savePathsProgress,
  });

  final List<Game> games;
  final Map<String, List<SaveSnapshot>> snapshots;

  /// Игры, процесс которых сейчас запущен.
  final Set<String> runningIds;

  /// Ключи выполняющихся операций — виджетам не нужен собственный `_busy`.
  final Set<String> busy;
  final bool loaded;
  final Notice? notice;

  /// Итог последней массовой операции: одной строкой «с ошибкой: 3»
  /// пользоваться нельзя — непонятно, какие игры и почему.
  final BulkReport? bulkReport;

  /// Ход подготовки базы путей, пока она качается и разбирается.
  final CatalogProgress? savePathsProgress;

  /// Пакеты `.evsave`, найденные в папке синхронизации.
  final List<SavePackageInfo> syncPackages;
  final bool scanningSync;
  final bool syncScanned;

  Game? gameById(String? id) {
    if (id == null) return null;
    for (final game in games) {
      if (game.id == id) return game;
    }
    return null;
  }

  List<SaveSnapshot> snapshotsFor(String gameId) =>
      snapshots[gameId] ?? const <SaveSnapshot>[];

  int get totalSnapshotCount =>
      snapshots.values.fold(0, (sum, list) => sum + list.length);

  bool isBusy(String key) => busy.contains(key);

  bool isRunning(String gameId) => runningIds.contains(gameId);

  LibraryState copyWith({
    List<Game>? games,
    Map<String, List<SaveSnapshot>>? snapshots,
    Set<String>? runningIds,
    Set<String>? busy,
    bool? loaded,
    Object? notice = _unset,
    List<SavePackageInfo>? syncPackages,
    bool? scanningSync,
    bool? syncScanned,
    Object? bulkReport = _unset,
    Object? savePathsProgress = _unset,
  }) {
    return LibraryState(
      games: games ?? this.games,
      snapshots: snapshots ?? this.snapshots,
      runningIds: runningIds ?? this.runningIds,
      busy: busy ?? this.busy,
      loaded: loaded ?? this.loaded,
      notice: notice == _unset ? this.notice : notice as Notice?,
      syncPackages: syncPackages ?? this.syncPackages,
      scanningSync: scanningSync ?? this.scanningSync,
      syncScanned: syncScanned ?? this.syncScanned,
      bulkReport: bulkReport == _unset
          ? this.bulkReport
          : bulkReport as BulkReport?,
      savePathsProgress: savePathsProgress == _unset
          ? this.savePathsProgress
          : savePathsProgress as CatalogProgress?,
    );
  }

  @override
  List<Object?> get props => [
    games,
    snapshots,
    runningIds,
    busy,
    loaded,
    bulkReport,
    savePathsProgress,
    notice,
    syncPackages,
    scanningSync,
    syncScanned,
  ];

  static const _unset = Object();
}
