import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/download_task.dart';

part 'download_history_event.dart';
part 'download_history_state.dart';

/// История скоростей одной загрузки — минута назад и до сейчас.
///
/// Движок присылает снимок примерно раз в секунду. История намеренно не
/// уходит ни в состояние блока загрузок, ни на диск: это данные для
/// показа, их незачем хранить между запусками и незачем подмешивать в
/// хозяйство торрент-клиента.
///
/// Свой блок, а не поле в `State` виджета, потому что **смотрят на неё из
/// двух мест сразу**: на странице игры график лежит подложкой под обложкой
/// и названием, а показания — скорость, пик, диск, отдача — стоят ниже, у
/// клавиш. Два независимых счётчика выборок дали бы две истории, считающие
/// одно и то же, и разойтись им ничего не мешало бы: довольно одному
/// смонтироваться на кадр позже. Держит его `DownloadHistoryScope`.
class DownloadHistoryBloc
    extends Bloc<DownloadHistoryEvent, DownloadSpeedHistory> {
  DownloadHistoryBloc(DownloadTask task)
    : _completedBytes = task.completedBytes,
      _sampledAt = DateTime.now(),
      super(
        DownloadSpeedHistory(
          samples: [SpeedSample(download: task.downloadSpeed, disk: 0)],
        ),
      ) {
    on<SpeedSampled>(_onSampled);
  }

  /// Минута при снимке раз в секунду.
  static const length = 60;

  DateTime _sampledAt;
  int _completedBytes;

  /// Добавляет выборку, если есть что добавлять.
  ///
  /// Скорость записи на диск считается сама: движок её не присылает, но
  /// прирост скачанного за прошедшее время — это она и есть. Разница между
  /// ней и сетевой скоростью и есть то, ради чего на графике две линии.
  void _onSampled(SpeedSampled event, Emitter<DownloadSpeedHistory> emit) {
    final task = event.task;
    final previous = event.previous;
    if (task.downloadSpeed == previous.downloadSpeed &&
        task.completedBytes == previous.completedBytes &&
        task.state == previous.state) {
      return;
    }

    final now = DateTime.now();
    final elapsedUs = now.difference(_sampledAt).inMicroseconds;
    final delta = task.completedBytes - _completedBytes;
    final diskSpeed = elapsedUs <= 0 || delta <= 0
        ? 0
        : (delta * Duration.microsecondsPerSecond / elapsedUs).round();
    // На паузе показываем нули, а не последние живые числа: замерший
    // график, повторяющий вчерашнюю скорость, читается как идущая загрузка.
    final paused = task.state == DownloadState.paused;
    final next = [
      ...state.samples,
      SpeedSample(
        download: paused ? 0 : task.downloadSpeed,
        disk: paused ? 0 : diskSpeed,
      ),
    ];
    _sampledAt = now;
    _completedBytes = task.completedBytes;
    emit(
      DownloadSpeedHistory(
        samples: next.length > length
            ? next.sublist(next.length - length)
            : next,
      ),
    );
  }
}
