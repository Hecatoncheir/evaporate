import 'dart:async';

import 'package:evaporate/bloc/download_history/download_history_bloc.dart';
import 'package:evaporate/models/download_task.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/wait_for_state.dart';

/// История скоростей одна на приложение: прежде она заводилась у каждого
/// места показа, умирала с виджетом, при замершей загрузке стояла на месте,
/// а обработчик её не исполнял ни один тест.
void main() {
  late StreamController<List<DownloadTask>> engine;
  late DateTime now;
  late DownloadHistoryBloc history;

  setUp(() {
    engine = StreamController();
    now = DateTime(2026, 9, 22, 12);
    history = DownloadHistoryBloc(tasks: engine.stream, now: () => now);
  });

  tearDown(() async {
    await history.close();
    await engine.close();
  });

  DownloadTask task(
    String id, {
    int speed = 0,
    int completed = 0,
    DownloadState state = DownloadState.active,
  }) => DownloadTask(
    id: id,
    name: id,
    state: state,
    downloadSpeed: speed,
    completedBytes: completed,
    totalBytes: 1 << 30,
  );

  /// Снимок движка через секунду после прошлого.
  Future<DownloadHistories> tick(List<DownloadTask> tasks) {
    now = now.add(const Duration(seconds: 1));
    final before = history.state;
    engine.add(tasks);
    return waitForState(history, (s) => !identical(s, before));
  }

  test('скорость диска считается по приросту за прошедшее время', () async {
    await tick([task('a', speed: 100, completed: 0)]);
    final state = await tick([task('a', speed: 100, completed: 4096)]);

    expect(state.of('a').samples.map((s) => s.disk), [0, 4096]);
    expect(state.of('a').diskSpeed, 4096);
  });

  // Прежде выборку добавляли, только когда что-то сдвинулось: замершая
  // загрузка не двигала график вовсе, и он стоял, как будто качается.
  test('замершая загрузка всё равно двигает график', () async {
    await tick([task('a', speed: 500, completed: 100)]);
    await tick([task('a', completed: 100)]);
    final state = await tick([task('a', completed: 100)]);

    expect(state.of('a').samples.map((s) => s.download), [500, 0, 0]);
  });

  test('у каждой задачи своя история, а снятая уходит', () async {
    await tick([task('a', speed: 1), task('b', speed: 2)]);
    final state = await tick([task('b', speed: 3)]);

    expect(state.of('a').samples, isEmpty);
    expect(state.of('b').samples.map((s) => s.download), [2, 3]);
  });

  test('на паузе — нули, а не последняя живая скорость', () async {
    await tick([task('a', speed: 900, completed: 0)]);
    final state = await tick([
      task('a', speed: 900, completed: 5000, state: DownloadState.paused),
    ]);

    expect(state.of('a').samples.last, const SpeedSample(download: 0, disk: 0));
  });

  test('история не длиннее минуты', () async {
    for (var i = 0; i < DownloadHistoryBloc.length + 5; i++) {
      await tick([task('a', speed: i)]);
    }

    final samples = history.state.of('a').samples;
    expect(samples, hasLength(DownloadHistoryBloc.length));
    expect(samples.last.download, DownloadHistoryBloc.length + 4);
  });
}
