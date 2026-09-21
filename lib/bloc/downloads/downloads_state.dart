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

  /// Всё незавершённое вне очереди: идущее, на паузе и сорвавшееся. Это и
  /// колонка «в работе» на странице загрузок, и число на метке в обойме —
  /// одно определение на оба места.
  List<DownloadTask> get inWork => [
    for (final t in tasks)
      if (!t.isQueued && t.state != DownloadState.complete) t,
  ];

  /// Держат слот очереди только идущие: пауза и ошибка его освобождают.
  /// По ним — показание «N / предел».
  List<DownloadTask> get holdingSlots => [
    for (final t in inWork)
      if (t.isRunning) t,
  ];

  /// Ждущие свободного слота, в порядке очереди.
  List<DownloadTask> get queued => [
    for (final t in tasks)
      if (t.isQueued) t,
  ];

  DownloadTask? taskById(String? id) {
    if (id == null) return null;
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  DownloadTask? taskForGame(Game game) =>
      taskById(game.download.downloadTaskId);

  /// Место в общем порядке задач, куда встать перед [beforeId].
  ///
  /// `null` — соседа нет в списке, переставлять некуда. Движку нужна
  /// позиция среди **всех** задач, а очередь — только их часть: знать это
  /// виджету незачем, поэтому перевод живёт здесь.
  int? orderIndexBefore(String? beforeId) {
    if (beforeId == null) return tasks.isEmpty ? null : tasks.length - 1;
    final index = tasks.indexWhere((task) => task.id == beforeId);
    return index == -1 ? null : index;
  }

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
