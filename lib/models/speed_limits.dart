import 'package:equatable/equatable.dart';

/// Ограничения скорости загрузок.
///
/// Значения — в килобайтах в секунду; ноль означает «без ограничения».
/// Отдельный предел на время игры — то, чего у обычного торрент-клиента быть
/// не может: он не знает, что вы сейчас играете, а лончер знает. Качая на
/// полную, легко испортить себе же отклик в игре, которую только что запустил.
class SpeedLimits extends Equatable {
  const SpeedLimits({
    this.download = 0,
    this.upload = 0,
    this.whilePlaying = 0,
    this.seedRatio = 0,
  });

  /// Предел на приём.
  final int download;

  /// Предел на раздачу. Совсем перекрывать её не стоит: раздача — плата за
  /// то, что скачал, и без неё торрент-обмен перестаёт работать.
  final int upload;

  /// Предел на приём, пока запущена игра. Ноль — не ограничивать особо.
  final int whilePlaying;

  /// До какого рейтинга раздавать, в сотых долях: 150 — это 1,5.
  ///
  /// Ноль означает «раздавать без предела». Целое число, а не дробь, чтобы
  /// значение переживало запись в файл настроек без сюрпризов округления.
  final int seedRatio;

  static const unlimited = SpeedLimits();

  bool get isUnlimited => download == 0 && upload == 0 && whilePlaying == 0;

  /// Пора ли останавливать раздачу.
  ///
  /// Нечего сравнивать, пока ничего не скачано: рейтинг от нуля
  /// не считается, а раздачу это остановило бы сразу.
  bool seedingDone({required int uploaded, required int downloaded}) {
    if (seedRatio <= 0 || downloaded <= 0) return false;
    return uploaded * 100 >= downloaded * seedRatio;
  }

  /// Сколько байт в секунду разрешено, или null, если без ограничения.
  static int? _bytes(int kilobytes) => kilobytes <= 0 ? null : kilobytes * 1024;

  int? get uploadBytes => _bytes(upload);

  /// Действующий предел приёма с учётом того, идёт ли сейчас игра.
  ///
  /// Когда игра запущена, выигрывает меньшее из двух: заданный предел на
  /// время игры не должен внезапно **поднять** скорость выше обычной.
  int? downloadBytes({required bool playing}) {
    if (!playing || whilePlaying <= 0) return _bytes(download);
    if (download <= 0) return _bytes(whilePlaying);
    return _bytes(download < whilePlaying ? download : whilePlaying);
  }

  SpeedLimits copyWith({
    int? download,
    int? upload,
    int? whilePlaying,
    int? seedRatio,
  }) {
    return SpeedLimits(
      download: download ?? this.download,
      upload: upload ?? this.upload,
      whilePlaying: whilePlaying ?? this.whilePlaying,
      seedRatio: seedRatio ?? this.seedRatio,
    );
  }

  Map<String, dynamic> toJson() => {
    'download': download,
    'upload': upload,
    'whilePlaying': whilePlaying,
    'seedRatio': seedRatio,
  };

  factory SpeedLimits.fromJson(Map<String, dynamic> json) => SpeedLimits(
    // Отрицательное значение бессмысленно и означало бы обратное ограничение,
    // поэтому приводим его к «без ограничения».
    download: _positive(json['download']),
    upload: _positive(json['upload']),
    whilePlaying: _positive(json['whilePlaying']),
    seedRatio: _positive(json['seedRatio']),
  );

  static int _positive(Object? value) {
    final number = value is int ? value : int.tryParse('$value') ?? 0;
    return number > 0 ? number : 0;
  }

  @override
  List<Object?> get props => [download, upload, whilePlaying, seedRatio];
}
