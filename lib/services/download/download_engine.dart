import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../models/download_task.dart';
import '../../models/proxy_settings.dart';
import '../../models/speed_limits.dart';
import 'integrity_check.dart';

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
}

/// Контракт движка загрузок. Единственная реализация — [DtorrentEngine],
/// встроенный BitTorrent-клиент на чистом Dart. Интерфейс намеренно узкий:
/// смена движка не должна трогать остальное приложение — так уже сменили
/// один раз, уйдя с внешнего бинарника ради SOCKS5 до самих пиров.
///
/// Узкий — не значит короче, чем им пользуются. Пока половины вызовов
/// блока здесь не было, он держал движок по конкретному типу, и проверить
/// его без настоящих раздач было нельзя: из тринадцати событий тесты
/// доходили до двух. Контракт описывает то, что движку поручают, — иначе
/// он описывает не движок, а его половину.
abstract class DownloadEngine {
  ValueListenable<EngineStatus> get status;

  /// Куда складывать скачанное. Меняется на ходу: путь установки живёт в
  /// настройках, и человек вправе сменить его между загрузками.
  abstract String downloadDir;

  /// Сколько задач качается одновременно; остальные ждут очереди.
  abstract int maxConcurrent;

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

  /// Раздаёт освободившиеся слоты очереди ожидающим задачам.
  void pumpQueue();

  /// Переставляет задачу на [newIndex] в общем порядке задач.
  Future<void> reorder(String id, int newIndex);

  /// Меняет прокси. Уже поднятые задачи перезапускаются: иначе их трафик
  /// продолжил бы идти по-старому.
  Future<void> setProxy(ProxySettings value);

  /// Файл раздачи, если движок им располагает. Пока метаданные
  /// magnet-ссылки не пришли, отдавать нечего.
  String? torrentPathFor(String id);

  /// Проверяет, что скачанное и правда лежит на диске целиком: пропавший
  /// или обрезанный файл хеши кусков уже не заметят.
  Future<IntegrityReport> verify(String id);

  /// Ограничить скорость. [playing] — идёт ли сейчас игра.
  Future<void> applyLimits(SpeedLimits limits, {required bool playing});

  void dispose();

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
