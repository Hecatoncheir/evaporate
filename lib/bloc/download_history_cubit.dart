import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/download_task.dart';

/// Одна выборка: что шло по сети и что легло на диск.
class SpeedSample extends Equatable {
  const SpeedSample({required this.download, required this.disk});

  final int download;
  final int disk;

  @override
  List<Object?> get props => [download, disk];
}

/// История скоростей одной загрузки — минута назад и до сейчас.
///
/// Движок присылает снимок примерно раз в секунду. История намеренно не
/// уходит ни в состояние блока загрузок, ни на диск: это данные для
/// показа, их незачем хранить между запусками и незачем подмешивать в
/// хозяйство торрент-клиента.
///
/// Cubit, а не поле в State виджета, потому что **смотрят на неё из двух
/// мест сразу**: на странице игры график лежит подложкой под обложкой и
/// названием, а показания — скорость, пик, диск, отдача — стоят ниже, у
/// клавиш. Два независимых счётчика выборок дали бы две истории, считающие
/// одно и то же, и разойтись им ничего не мешало бы: довольно одному
/// смонтироваться на кадр позже.
///
/// Событий здесь нет и не нужно: выборку подаёт тот, у кого есть задача, и
/// подаёт молча. Где событие ничего не добавляет, Cubit — тот же блок без
/// обряда.
class DownloadHistoryCubit extends Cubit<List<SpeedSample>> {
  DownloadHistoryCubit(DownloadTask task)
    : _completedBytes = task.completedBytes,
      _sampledAt = DateTime.now(),
      super([SpeedSample(download: task.downloadSpeed, disk: 0)]);

  /// Минута при снимке раз в секунду.
  static const length = 60;

  DateTime _sampledAt;
  int _completedBytes;

  /// Принимает новое состояние задачи и добавляет выборку, если есть что
  /// добавлять.
  ///
  /// Скорость записи на диск считается сама: движок её не присылает, но
  /// прирост скачанного за прошедшее время — это она и есть. Разница между
  /// ней и сетевой скоростью и есть то, ради чего на графике две линии.
  void sample(DownloadTask task, DownloadTask previous) {
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
      ...state,
      SpeedSample(
        download: paused ? 0 : task.downloadSpeed,
        disk: paused ? 0 : diskSpeed,
      ),
    ];
    _sampledAt = now;
    _completedBytes = task.completedBytes;
    emit(next.length > length ? next.sublist(next.length - length) : next);
  }

  /// Наибольшая сетевая скорость за всю историю — показание «пик».
  int peakOf(DownloadTask task) => state.fold<int>(
    task.downloadSpeed,
    (value, sample) => sample.download > value ? sample.download : value,
  );

  /// Последняя посчитанная скорость записи на диск.
  int get diskSpeed => state.isEmpty ? 0 : state.last.disk;
}
