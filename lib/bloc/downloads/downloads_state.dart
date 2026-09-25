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

  /// Всё незавершённое вне очереди: идущее, на паузе и сорвавшееся. Это
  /// колонка «в работе» на странице загрузок; число на кнопке рейла —
  /// оно же вместе с очередью ([queued]).
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
  ///
  /// Позиция — после того, как [moving] вынут из списка: движок сначала
  /// вынимает задачу, потом вставляет. Стоит она выше соседа — сосед после
  /// этого сдвигается на одну, и без поправки «a перед c» ставило a за c.
  int? orderIndexBefore(String? beforeId, {String? moving}) {
    if (beforeId == null) return tasks.isEmpty ? null : tasks.length - 1;
    final index = tasks.indexWhere((task) => task.id == beforeId);
    if (index == -1) return null;
    final from = tasks.indexWhere((task) => task.id == moving);
    return from != -1 && from < index ? index - 1 : index;
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
