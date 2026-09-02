import 'package:equatable/equatable.dart';

enum DownloadState { waiting, active, paused, complete, error, removed }

/// Состояние одной загрузки, нормализованное под UI.
/// Задачи движка маппятся в эту модель — UI о самом движке не знает.
class DownloadTask extends Equatable {
  const DownloadTask({
    required this.id,
    required this.name,
    required this.state,
    this.totalBytes = 0,
    this.completedBytes = 0,
    this.downloadSpeed = 0,
    this.uploadSpeed = 0,
    this.uploadedBytes = 0,
    this.connections = 0,
    this.seeders = 0,
    this.dir,
    this.files = const [],
    this.errorMessage,
    this.isMetadata = false,
    this.followedBy,
    this.infoHash,
    this.isQueued = false,
  });

  final String id;
  final String name;
  final DownloadState state;
  final int totalBytes;
  final int completedBytes;
  final int downloadSpeed;
  final int uploadSpeed;

  /// Сколько отдано другим за всё время. Раздача — плата за скачанное, и
  /// пользователь вправе видеть, сколько он её внёс.
  final int uploadedBytes;
  final int connections;
  final int seeders;
  final String? dir;
  final List<String> files;
  final String? errorMessage;

  /// Скачивание метаданных magnet-ссылки: короткая задача, которая затем
  /// порождает настоящую загрузку ([followedBy]).
  final bool isMetadata;
  final String? followedBy;

  /// Infohash торрента. После перезапуска приложения идентификатор задачи
  /// меняется, и связать её с игрой можно только по нему.
  final String? infoHash;

  /// Задача ждёт свободного слота: скачивание начнётся, когда закончится
  /// что-то из активных.
  final bool isQueued;

  double get progress {
    if (totalBytes <= 0) return 0;
    return (completedBytes / totalBytes).clamp(0.0, 1.0);
  }

  int get remainingBytes => (totalBytes - completedBytes).clamp(0, totalBytes);

  int get etaSeconds {
    if (downloadSpeed <= 0 || totalBytes <= 0) return 0;
    return remainingBytes ~/ downloadSpeed;
  }

  bool get isFinished => state == DownloadState.complete;

  bool get isRunning =>
      state == DownloadState.active || state == DownloadState.waiting;

  @override
  List<Object?> get props => [
    id,
    name,
    state,
    totalBytes,
    completedBytes,
    downloadSpeed,
    uploadSpeed,
    uploadedBytes,
    connections,
    seeders,
    dir,
    files,
    errorMessage,
    isMetadata,
    followedBy,
    infoHash,
    isQueued,
  ];

  /// Для журналов. В интерфейсе состояние показывает `downloadStateLabel`.
  String get stateLabel => switch (state) {
    DownloadState.waiting => 'В очереди',
    DownloadState.active => isMetadata ? 'Метаданные' : 'Загрузка',
    DownloadState.paused => 'Пауза',
    DownloadState.complete => 'Готово',
    DownloadState.error => 'Ошибка',
    DownloadState.removed => 'Отменено',
  };
}

/// Итоговая статистика движка для строки состояния.
class EngineStats extends Equatable {
  const EngineStats({
    this.downloadSpeed = 0,
    this.uploadSpeed = 0,
    this.activeCount = 0,
    this.waitingCount = 0,
  });

  final int downloadSpeed;
  final int uploadSpeed;
  final int activeCount;
  final int waitingCount;

  @override
  List<Object?> get props => [
    downloadSpeed,
    uploadSpeed,
    activeCount,
    waitingCount,
  ];
}
