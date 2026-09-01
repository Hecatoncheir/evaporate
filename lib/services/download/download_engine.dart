import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../models/download_task.dart';

enum EngineState {
  /// Движок ещё не запускали.
  stopped,
  starting,
  ready,

  /// Бинарник aria2c не найден — приложение работает, но без загрузок.
  missingBinary,
  failed,
}

class EngineStatus extends Equatable {
  const EngineStatus(this.state, {this.message, this.binaryPath});

  final EngineState state;
  final String? message;
  final String? binaryPath;

  bool get isReady => state == EngineState.ready;

  @override
  List<Object?> get props => [state, message, binaryPath];

  String get label => switch (state) {
    EngineState.stopped => 'Остановлен',
    EngineState.starting => 'Запускается…',
    EngineState.ready => 'Готов',
    EngineState.missingBinary => 'aria2c не найден',
    EngineState.failed => 'Ошибка',
  };
}

/// Контракт движка загрузок. Реализация на aria2 живёт в [Aria2Engine];
/// интерфейс намеренно узкий, чтобы позже можно было подставить
/// встроенный BitTorrent-клиент на чистом Dart, не трогая остальное приложение.
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
