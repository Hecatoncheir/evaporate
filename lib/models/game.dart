import 'save_profile.dart';

enum GameSourceKind { magnet, torrentFile, localFolder }

/// Откуда игра берётся. Приложение не содержит каталога контента —
/// источник всегда задаёт пользователь.
class GameSource {
  const GameSource({required this.kind, required this.value});

  final GameSourceKind kind;

  /// magnet-ссылка, путь к .torrent, либо путь к уже готовой папке.
  final String value;

  String get label => switch (kind) {
    GameSourceKind.magnet => 'Magnet-ссылка',
    GameSourceKind.torrentFile => 'Torrent-файл',
    GameSourceKind.localFolder => 'Локальная папка',
  };

  Map<String, dynamic> toJson() => {'kind': kind.name, 'value': value};

  factory GameSource.fromJson(Map<String, dynamic> json) => GameSource(
    kind: GameSourceKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => GameSourceKind.magnet,
    ),
    value: json['value'] as String,
  );
}

enum GameStatus { notInstalled, downloading, paused, installed, running, error }

class Game {
  Game({
    required this.id,
    required this.title,
    required this.addedAt,
    this.source,
    this.installDir,
    this.executablePath,
    this.launchArgs = const [],
    this.coverPath,
    this.coverUrl,
    this.description,
    this.steamAppId,
    this.notes,
    this.saveProfile = const SaveProfile(),
    this.playtime = Duration.zero,
    this.lastPlayed,
    this.status = GameStatus.notInstalled,
    this.downloadGid,
    this.infoHash,
    this.sizeBytes = 0,
    this.lastError,
  });

  final String id;
  final String title;
  final DateTime addedAt;
  final GameSource? source;

  /// Куда установлена (папка загрузки торрента либо выбранная пользователем).
  final String? installDir;

  /// Абсолютный путь к исполняемому файлу или .app-бандлу.
  final String? executablePath;
  final List<String> launchArgs;
  final String? coverPath;

  /// Обложка из каталога Steam: показывается прямо по ссылке, локально
  /// ничего не скачиваем.
  final String? coverUrl;
  final String? description;

  /// Идентификатор в Steam — чтобы не искать игру повторно.
  final int? steamAppId;
  final String? notes;
  final SaveProfile saveProfile;
  final Duration playtime;
  final DateTime? lastPlayed;
  final GameStatus status;

  /// Идентификатор задачи в движке загрузок, пока она жива.
  final String? downloadGid;

  /// Infohash торрента — устойчивая связь с задачей движка: gid живёт
  /// только до перезапуска aria2, infohash не меняется никогда.
  final String? infoHash;
  final int sizeBytes;
  final String? lastError;

  bool get isInstalled =>
      status == GameStatus.installed || status == GameStatus.running;

  bool get canLaunch => executablePath != null && executablePath!.isNotEmpty;

  Game copyWith({
    String? title,
    Object? source = _u,
    Object? installDir = _u,
    Object? executablePath = _u,
    List<String>? launchArgs,
    Object? coverPath = _u,
    Object? coverUrl = _u,
    Object? description = _u,
    Object? steamAppId = _u,
    Object? notes = _u,
    SaveProfile? saveProfile,
    Duration? playtime,
    Object? lastPlayed = _u,
    GameStatus? status,
    Object? downloadGid = _u,
    Object? infoHash = _u,
    int? sizeBytes,
    Object? lastError = _u,
  }) {
    return Game(
      id: id,
      title: title ?? this.title,
      addedAt: addedAt,
      source: source == _u ? this.source : source as GameSource?,
      installDir: installDir == _u ? this.installDir : installDir as String?,
      executablePath: executablePath == _u
          ? this.executablePath
          : executablePath as String?,
      launchArgs: launchArgs ?? this.launchArgs,
      coverPath: coverPath == _u ? this.coverPath : coverPath as String?,
      coverUrl: coverUrl == _u ? this.coverUrl : coverUrl as String?,
      description: description == _u
          ? this.description
          : description as String?,
      steamAppId: steamAppId == _u ? this.steamAppId : steamAppId as int?,
      notes: notes == _u ? this.notes : notes as String?,
      saveProfile: saveProfile ?? this.saveProfile,
      playtime: playtime ?? this.playtime,
      lastPlayed: lastPlayed == _u ? this.lastPlayed : lastPlayed as DateTime?,
      status: status ?? this.status,
      downloadGid: downloadGid == _u
          ? this.downloadGid
          : downloadGid as String?,
      infoHash: infoHash == _u ? this.infoHash : infoHash as String?,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      lastError: lastError == _u ? this.lastError : lastError as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'addedAt': addedAt.toIso8601String(),
    if (source != null) 'source': source!.toJson(),
    if (installDir != null) 'installDir': installDir,
    if (executablePath != null) 'executablePath': executablePath,
    'launchArgs': launchArgs,
    if (coverPath != null) 'coverPath': coverPath,
    if (notes != null) 'notes': notes,
    'saveProfile': saveProfile.toJson(),
    'playtimeSeconds': playtime.inSeconds,
    if (lastPlayed != null) 'lastPlayed': lastPlayed!.toIso8601String(),
    'status': status.name,
    if (downloadGid != null) 'downloadGid': downloadGid,
    if (infoHash != null) 'infoHash': infoHash,
    'sizeBytes': sizeBytes,
    if (lastError != null) 'lastError': lastError,
  };

  factory Game.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'] as String?;
    var status = GameStatus.values.firstWhere(
      (s) => s.name == rawStatus,
      orElse: () => GameStatus.notInstalled,
    );
    // «Запущена» — состояние времени выполнения: после перезапуска приложения
    // процесса игры уже нет.
    if (status == GameStatus.running) status = GameStatus.installed;
    return Game(
      id: json['id'] as String,
      title: json['title'] as String,
      addedAt:
          DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
      source: json['source'] == null
          ? null
          : GameSource.fromJson(json['source'] as Map<String, dynamic>),
      installDir: json['installDir'] as String?,
      executablePath: json['executablePath'] as String?,
      launchArgs: (json['launchArgs'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      coverPath: json['coverPath'] as String?,
      coverUrl: json['coverUrl'] as String?,
      description: json['description'] as String?,
      steamAppId: json['steamAppId'] as int?,
      notes: json['notes'] as String?,
      saveProfile: json['saveProfile'] == null
          ? const SaveProfile()
          : SaveProfile.fromJson(json['saveProfile'] as Map<String, dynamic>),
      playtime: Duration(seconds: json['playtimeSeconds'] as int? ?? 0),
      lastPlayed: DateTime.tryParse(json['lastPlayed'] as String? ?? ''),
      status: status,
      downloadGid: json['downloadGid'] as String?,
      infoHash: json['infoHash'] as String?,
      sizeBytes: json['sizeBytes'] as int? ?? 0,
      lastError: json['lastError'] as String?,
    );
  }

  static const _u = Object();
}
