part of 'downloads_bloc.dart';

class DownloadsState extends Equatable {
  const DownloadsState({
    this.tasks = const [],
    this.stats = const EngineStats(),
    this.engine = const EngineStatus(EngineState.stopped),
    this.notice,
  });

  final List<DownloadTask> tasks;
  final EngineStats stats;
  final EngineStatus engine;
  final Notice? notice;

  List<DownloadTask> get activeTasks => tasks
      .where((t) => t.isRunning || t.state == DownloadState.paused)
      .toList();

  DownloadTask? taskById(String? id) {
    if (id == null) return null;
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  DownloadTask? taskForGame(Game game) => taskById(game.downloadGid);

  DownloadsState copyWith({
    List<DownloadTask>? tasks,
    EngineStats? stats,
    EngineStatus? engine,
    Object? notice = _unset,
  }) {
    return DownloadsState(
      tasks: tasks ?? this.tasks,
      stats: stats ?? this.stats,
      engine: engine ?? this.engine,
      notice: notice == _unset ? this.notice : notice as Notice?,
    );
  }

  @override
  List<Object?> get props => [tasks, stats, engine, notice];

  static const _unset = Object();
}
