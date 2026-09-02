import 'save_profile.dart';

/// Снимок сохранений: zip-архив в хранилище приложения плюс метаданные.
/// Тот же формат используется для экспорта на другое устройство (.evsave).
class SaveSnapshot {
  const SaveSnapshot({
    required this.id,
    required this.gameId,
    required this.gameTitle,
    required this.createdAt,
    required this.deviceName,
    required this.platform,
    required this.sizeBytes,
    required this.archivePath,
    required this.rules,
    this.playtime = Duration.zero,
    this.note,
    this.fileCount = 0,
    this.origin = SnapshotOrigin.manual,
  });

  final String id;
  final String gameId;
  final String gameTitle;
  final DateTime createdAt;
  final String deviceName;
  final String platform;
  final int sizeBytes;
  final String archivePath;

  /// Правила путей на момент снимка — нужны, чтобы разложить файлы обратно
  /// даже если игра пришла на новое устройство вместе с сейвом.
  final List<SavePathRule> rules;
  final Duration playtime;
  final String? note;
  final int fileCount;
  final SnapshotOrigin origin;

  SaveSnapshot copyWith({String? archivePath, String? note}) => SaveSnapshot(
    id: id,
    gameId: gameId,
    gameTitle: gameTitle,
    createdAt: createdAt,
    deviceName: deviceName,
    platform: platform,
    sizeBytes: sizeBytes,
    archivePath: archivePath ?? this.archivePath,
    rules: rules,
    playtime: playtime,
    note: note ?? this.note,
    fileCount: fileCount,
    origin: origin,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'gameId': gameId,
    'gameTitle': gameTitle,
    'createdAt': createdAt.toIso8601String(),
    'deviceName': deviceName,
    'platform': platform,
    'sizeBytes': sizeBytes,
    'archivePath': archivePath,
    'rules': rules.map((r) => r.toJson()).toList(),
    'playtimeSeconds': playtime.inSeconds,
    if (note != null) 'note': note,
    'fileCount': fileCount,
    'origin': origin.name,
  };

  factory SaveSnapshot.fromJson(Map<String, dynamic> json) => SaveSnapshot(
    id: json['id'] as String,
    gameId: json['gameId'] as String,
    gameTitle: json['gameTitle'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    deviceName: json['deviceName'] as String? ?? '',
    platform: json['platform'] as String? ?? '',
    sizeBytes: json['sizeBytes'] as int? ?? 0,
    archivePath: json['archivePath'] as String? ?? '',
    rules: (json['rules'] as List<dynamic>? ?? [])
        .map((e) => SavePathRule.fromJson(e as Map<String, dynamic>))
        .toList(),
    playtime: Duration(seconds: json['playtimeSeconds'] as int? ?? 0),
    note: json['note'] as String?,
    fileCount: json['fileCount'] as int? ?? 0,
    origin: SnapshotOrigin.values.firstWhere(
      (o) => o.name == json['origin'],
      orElse: () => SnapshotOrigin.manual,
    ),
  );

  /// Манифест внутри архива — то, что читает другое устройство при импорте.
  Map<String, dynamic> toManifest() => {
    'format': manifestFormat,
    'id': id,
    'gameId': gameId,
    'gameTitle': gameTitle,
    'createdAt': createdAt.toIso8601String(),
    'deviceName': deviceName,
    'platform': platform,
    'playtimeSeconds': playtime.inSeconds,
    'fileCount': fileCount,
    'sizeBytes': sizeBytes,
    if (note != null) 'note': note,
    'rules': rules.map((r) => r.toJson()).toList(),
  };

  /// Формат, которым подписываются новые пакеты.
  static const manifestFormat = 'evaporate.save/1';

  /// Форматы, которые эта сборка умеет читать.
  ///
  /// Множество, а не сравнение с [manifestFormat]: пакеты живут на дисках и
  /// в облачных папках дольше, чем версия приложения. Проверка на равенство
  /// означала бы, что в день перехода на `/2` сборка перестала читать всё
  /// снятое раньше — то есть ровно ту переносимость, ради которой формат и
  /// подписан версией. Добавляя новую версию, старую отсюда не убирают,
  /// пока где-то могут лежать такие пакеты.
  static const readableFormats = {manifestFormat};
  static const manifestEntry = 'manifest.json';
  static const dataPrefix = 'data';
  static const fileExtension = '.evsave';
}

enum SnapshotOrigin { manual, autoOnExit, imported, preRestore }

extension SnapshotOriginLabel on SnapshotOrigin {
  /// Для журналов. В интерфейсе — `snapshotOriginLabel`.
  String get label => switch (this) {
    SnapshotOrigin.manual => 'Вручную',
    SnapshotOrigin.autoOnExit => 'Авто после игры',
    SnapshotOrigin.imported => 'Импорт',
    SnapshotOrigin.preRestore => 'Бэкап перед откатом',
  };
}
