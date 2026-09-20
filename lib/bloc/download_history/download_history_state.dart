part of 'download_history_bloc.dart';

/// Одна выборка: что шло по сети и что легло на диск.
class SpeedSample extends Equatable {
  const SpeedSample({required this.download, required this.disk});

  final int download;
  final int disk;

  @override
  List<Object?> get props => [download, disk];
}

/// Минута скоростей и показания, которые из неё следуют.
///
/// Пик и скорость диска — геттеры состояния, а не счёт в `build`: их
/// показывают рядом с графиком, и считаться они должны от той же истории,
/// что он рисует.
class DownloadSpeedHistory extends Equatable {
  const DownloadSpeedHistory({required this.samples});

  final List<SpeedSample> samples;

  /// Наибольшая сетевая скорость за всю историю — показание «пик».
  ///
  /// Текущая скорость задачи участвует наравне с историей: выборку
  /// добавляют не на каждый кадр, и пик, взятый только по ней, отставал бы
  /// от того, что человек видит прямо сейчас.
  int peakOf(DownloadTask task) => samples.fold<int>(
    task.downloadSpeed,
    (value, sample) => sample.download > value ? sample.download : value,
  );

  /// Последняя посчитанная скорость записи на диск.
  int get diskSpeed => samples.isEmpty ? 0 : samples.last.disk;

  @override
  List<Object?> get props => [samples];
}
