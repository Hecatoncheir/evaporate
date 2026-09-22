import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/download_task.dart';
import '../frequent_event.dart';

part 'download_history_event.dart';
part 'download_history_state.dart';

/// Истории скоростей всех загрузок — минута назад и до сейчас, по задаче.
///
/// Движок присылает снимок задач примерно раз в секунду. История намеренно
/// не уходит ни в состояние блока загрузок, ни на диск: это данные для
/// показа, их незачем хранить между запусками и незачем подмешивать в
/// хозяйство торрент-клиента.
///
/// **Один блок на приложение, а не на виджет.** Прежде история заводилась
/// в `DownloadHistoryScope` вокруг каждого места показа, и у одной задачи
/// их было две: карточка на странице загрузок и страница игры живут в
/// `IndexedStack` одновременно. История умирала вместе с виджетом —
/// перелистнул игру и вернулся, минута начиналась с нуля, — а при замершей
/// загрузке выборок не было вовсе: их добавляли, только когда что-то
/// сдвинулось, и график стоял, как будто качается. Теперь выборка — на
/// каждом снимке движка, по каждой задаче, и смотрят на неё все, кто
/// показывает.
class DownloadHistoryBloc
    extends Bloc<DownloadHistoryEvent, DownloadHistories> {
  DownloadHistoryBloc({
    required Stream<List<DownloadTask>> tasks,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const DownloadHistories()) {
    on<TasksSampled>(_onSampled);
    _subscription = tasks.listen((snapshot) => add(TasksSampled(snapshot)));
  }

  /// Минута при снимке раз в секунду.
  static const length = 60;

  /// Часы. Подменяются в тестах: скорость диска считается по прошедшему
  /// времени, и настоящие часы делали бы её случайной.
  final DateTime Function() _now;

  late final StreamSubscription<List<DownloadTask>> _subscription;

  /// Когда и сколько было скачано при прошлой выборке, по задаче.
  final Map<String, ({DateTime at, int completed})> _last = {};

  void _onSampled(TasksSampled event, Emitter<DownloadHistories> emit) {
    final now = _now();
    final next = <String, DownloadSpeedHistory>{
      for (final task in event.tasks)
        task.id: DownloadSpeedHistory(
          samples: _appended(state.of(task.id).samples, _sample(task, now)),
        ),
    };
    // Снятые задачи уходят и отсюда: их историю больше никто не покажет.
    _last.removeWhere((id, _) => !next.containsKey(id));
    emit(DownloadHistories(next));
  }

  /// Выборка по задаче сейчас.
  ///
  /// Скорость записи на диск считается сама: движок её не присылает, но
  /// прирост скачанного за прошедшее время — это она и есть. Разница между
  /// ней и сетевой скоростью и есть то, ради чего на графике две линии.
  SpeedSample _sample(DownloadTask task, DateTime now) {
    final last = _last[task.id];
    _last[task.id] = (at: now, completed: task.completedBytes);
    // На паузе показываем нули, а не последние живые числа: замерший
    // график, повторяющий вчерашнюю скорость, читается как идущая загрузка.
    if (task.state == DownloadState.paused) {
      return const SpeedSample(download: 0, disk: 0);
    }
    return SpeedSample(
      download: task.downloadSpeed,
      disk: _diskSpeed(last, task, now),
    );
  }

  static int _diskSpeed(
    ({DateTime at, int completed})? last,
    DownloadTask task,
    DateTime now,
  ) {
    if (last == null) return 0;
    final elapsedUs = now.difference(last.at).inMicroseconds;
    final delta = task.completedBytes - last.completed;
    if (elapsedUs <= 0 || delta <= 0) return 0;
    return (delta * Duration.microsecondsPerSecond / elapsedUs).round();
  }

  static List<SpeedSample> _appended(
    List<SpeedSample> samples,
    SpeedSample sample,
  ) {
    final next = [...samples, sample];
    return next.length > length ? next.sublist(next.length - length) : next;
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
