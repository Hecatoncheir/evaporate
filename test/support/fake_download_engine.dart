import 'package:evaporate/models/download_task.dart';
import 'package:evaporate/models/proxy_settings.dart';
import 'package:evaporate/models/speed_limits.dart';
import 'package:evaporate/services/download/download_engine.dart';
import 'package:evaporate/services/download/integrity_check.dart';
import 'package:flutter/foundation.dart';

/// Движок, который ничего не качает, но помнит, что ему поручали.
///
/// Настоящий `DtorrentEngine` требует живых раздач и сети, поэтому
/// половина событий блока не исполнялась ни разу. Здесь исполняются все:
/// поручения записываются, а ответы — статус, задачи, отчёт о целости —
/// задаёт сам тест.
class FakeDownloadEngine implements DownloadEngine {
  FakeDownloadEngine({this.downloadDir = '/dl', this.maxConcurrent = 3});

  @override
  String downloadDir;

  @override
  int maxConcurrent;

  final _status = ValueNotifier<EngineStatus>(
    const EngineStatus(EngineState.stopped),
  );
  final _tasks = ValueNotifier<List<DownloadTask>>(const []);
  final _stats = ValueNotifier<EngineStats>(const EngineStats());

  @override
  ValueListenable<EngineStatus> get status => _status;

  @override
  ValueListenable<List<DownloadTask>> get tasks => _tasks;

  @override
  ValueListenable<EngineStats> get stats => _stats;

  /// Что поручали, по порядку: `pause task-1`, `remove task-1` и так далее.
  /// Порядок важен сам по себе — отмена обязана снять задачу до того, как
  /// пойдёт удаление файлов.
  final List<String> calls = [];

  /// Чем отвечать на `addMagnet` и `addTorrentFile`.
  String nextTaskId = 'task-1';

  /// Чем отвечать на `verify`: по умолчанию «всё на месте».
  IntegrityReport report = const IntegrityReport(checkedFiles: 1);

  /// Куда движок якобы положил файл раздачи.
  String? torrentPath;

  /// Чем ответить на **ближайшее** поручение: отказом или ничем.
  ///
  /// Одноразово нарочно. Отказ, живущий до конца теста, встретил бы потом
  /// и закрытие блока — а `close` останавливает движок, и тест падал бы
  /// не там, где проверял.
  Exception? failure;

  ProxySettings? appliedProxy;
  SpeedLimits? appliedLimits;
  bool? appliedPlaying;

  void _record(String call) {
    calls.add(call);
    final error = failure;
    if (error == null) return;
    failure = null;
    throw error;
  }

  /// Движок готов принимать задачи.
  void becomeReady() => _status.value = const EngineStatus(EngineState.ready);

  /// Снимок задач от движка — так же, как его шлёт настоящий опрос.
  void emit(List<DownloadTask> value) => _tasks.value = value;

  @override
  Future<String> addMagnet(String uri, {required String dir}) async {
    _record('addMagnet $uri -> $dir');
    return nextTaskId;
  }

  @override
  Future<String> addTorrentFile(String path, {required String dir}) async {
    _record('addTorrentFile $path -> $dir');
    return nextTaskId;
  }

  @override
  Future<void> start() async => _record('start');

  @override
  Future<void> stop() async => _record('stop');

  @override
  Future<void> pause(String id) async => _record('pause $id');

  @override
  Future<void> resume(String id) async => _record('resume $id');

  @override
  Future<void> remove(String id) async => _record('remove $id');

  @override
  Future<void> refresh() async => _record('refresh');

  @override
  void pumpQueue() => _record('pumpQueue');

  @override
  Future<void> reorder(String id, int newIndex) async =>
      _record('reorder $id -> $newIndex');

  @override
  Future<void> setProxy(ProxySettings value) async {
    appliedProxy = value;
    _record('setProxy');
  }

  @override
  Future<void> applyLimits(SpeedLimits limits, {required bool playing}) async {
    appliedLimits = limits;
    appliedPlaying = playing;
    _record('applyLimits');
  }

  @override
  String? torrentPathFor(String id) => torrentPath;

  @override
  Future<IntegrityReport> verify(String id) async {
    _record('verify $id');
    return report;
  }

  @override
  DownloadTask? taskById(String id) {
    for (final task in _tasks.value) {
      if (task.id == id) return task;
    }
    return null;
  }

  @override
  void dispose() {
    _status.dispose();
    _tasks.dispose();
    _stats.dispose();
  }
}
