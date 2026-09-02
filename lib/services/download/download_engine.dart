import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../models/download_task.dart';
import '../../models/speed_limits.dart';

enum EngineState {
  /// Движок ещё не запускали.
  stopped,
  starting,
  ready,
  failed,
}

class EngineStatus extends Equatable {
  const EngineStatus(this.state, {this.message});

  final EngineState state;
  final String? message;

  bool get isReady => state == EngineState.ready;

  @override
  List<Object?> get props => [state, message];

  /// Для журналов. Пользователю состояние показывают словами через
  /// `engineStateLabel` в слое интерфейса — здесь языка нет.
  String get label => switch (state) {
    EngineState.stopped => 'stopped',
    EngineState.starting => 'starting',
    EngineState.ready => 'ready',
    EngineState.failed => 'failed',
  };
}

/// Контракт движка загрузок. Единственная реализация — [DtorrentEngine],
/// встроенный BitTorrent-клиент на чистом Dart. Интерфейс намеренно узкий:
/// смена движка не должна трогать остальное приложение — так уже сменили
/// один раз, уйдя с внешнего бинарника ради SOCKS5 до самих пиров.
abstract class DownloadEngine {
  ValueListenable<EngineStatus> get status;

  /// Текущий снимок задач; обновляется по опросу движка.
  ValueListenable<List<DownloadTask>> get tasks;

  ValueListenable<EngineStats> get stats;

  Future<void> start();

  Future<void> stop();

  /// Возвращает идентификатор задачи.
  Future<String> addMagnet(String uri, {required String dir});

  Future<String> addTorrentFile(String path, {required String dir});

  Future<void> pause(String id);

  Future<void> resume(String id);

  Future<void> remove(String id);

  /// Разовое обновление списка задач вне обычного цикла опроса.
  Future<void> refresh();

  /// Ограничить скорость. [playing] — идёт ли сейчас игра.
  Future<void> applyLimits(SpeedLimits limits, {required bool playing});

  DownloadTask? taskById(String id) {
    for (final task in tasks.value) {
      if (task.id == id) return task;
    }
    return null;
  }
}

class DownloadEngineException implements Exception {
  DownloadEngineException(this.message);

  final String message;

  @override
  String toString() => message;
}
