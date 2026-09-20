part of 'dtorrent_engine.dart';

/// Пределы скорости и остановка раздачи по рейтингу.
///
/// Сами пределы остались полем движка: расширение полей не заводит. А всё,
/// что с ними делают, собрано здесь — и живёт только внутри библиотеки,
/// поэтому расширение приватное.
extension _EngineLimits on DtorrentEngine {
  /// Публичного способа задать предел разом у движка нет — есть окно
  /// расписания у задачи. Ставим одно окно на все дни и все сутки:
  /// расписанием мы не пользуемся, нужен только предел скорости.
  void _limitTask(dt.TorrentTask task) {
    final download = _limits.downloadBytes(playing: _playing);
    final upload = _limits.uploadBytes;
    if (download == null && upload == null) {
      task.removeScheduleWindow(_limitWindowId);
      return;
    }
    task.addScheduleWindow(
      dt.ScheduleWindow(
        id: _limitWindowId,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        start: Duration.zero,
        end: const Duration(hours: 23, minutes: 59),
        maxDownloadRate: download,
        maxUploadRate: upload,
        // Иначе вне окна задача встала бы на паузу — а окно у нас
        // круглосуточное только по недосмотру расписания.
        pauseOutsideWindow: false,
      ),
    );
  }

  static const _limitWindowId = 'evaporate-speed-limit';

  /// Останавливает раздачу, когда заданный рейтинг достигнут.
  ///
  /// Проверяем при каждом опросе, а не по событию: движок о рейтинге ничего
  /// не знает, а отданное растёт постепенно. Остановленную задачу очередь
  /// больше не поднимает — для неё это выглядит как пауза от пользователя.
  void _stopSeedingIfDone(_ManagedDownload managed, DownloadTask task) {
    if (!managed.isActive || task.state != DownloadState.complete) return;
    if (!_limits.seedingDone(
      uploaded: task.uploadedBytes,
      downloaded: task.completedBytes,
    )) {
      return;
    }
    managed.markPaused();
    // pause() у движка синхронный, оборачивать его не во что.
    managed.task?.pause();
    unawaited(_persist());
  }
}
