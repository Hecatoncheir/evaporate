import 'package:equatable/equatable.dart';

import 'download_link.dart';
import 'game_details.dart';
import 'play_stats.dart';
import 'save_discovery.dart';
import 'save_profile.dart';

// Части игры лежат своими файлами, а зовут их отсюда по всему приложению:
// с разбором модели не должен был поменяться ни один импорт.
export 'download_link.dart';
export 'game_details.dart';
export 'game_source.dart';
export 'play_stats.dart';
export 'save_discovery.dart';

enum GameStatus { notInstalled, downloading, paused, installed, running, error }

/// Игра в библиотеке.
///
/// Прежде это были двадцать семь полей подряд, и `copyWith` на шестьдесят
/// строк правил их все одним вызовом: событие о загрузке могло задеть
/// обложку, а находка Steam — наигранное время, и держалось это только на
/// том, что никто так не писал. Теперь то, что приходит и правится вместе,
/// лежит одним значением — [details], [saveDiscovery], [download], [play], —
/// и правка одного не может задеть другое уже по устройству.
///
/// Здесь осталось то, что и есть сама игра: как называется, где лежит,
/// что запускать, что с ней сейчас и какие у неё правила сохранений.
///
/// На диске запись прежняя, плоская: части читают свои ключи из общей
/// карты и туда же пишут. `library.json` лежит у людей на дисках, и
/// разбор модели его касаться не должен.
class Game extends Equatable {
  const Game({
    required this.id,
    required this.title,
    required this.addedAt,
    this.installDir,
    this.executablePath,
    this.launchArgs = const [],
    this.notes,
    this.saveProfile = const SaveProfile(),
    this.status = GameStatus.notInstalled,
    this.sizeBytes = 0,
    this.lastError,
    this.details = const GameDetails(),
    this.saveDiscovery = const SaveDiscovery(),
    this.download = const DownloadLink(),
    this.play = const PlayStats(),
  });

  final String id;
  final String title;
  final DateTime addedAt;

  /// Куда установлена (папка загрузки торрента либо выбранная пользователем).
  final String? installDir;

  /// Абсолютный путь к исполняемому файлу или .app-бандлу.
  final String? executablePath;
  final List<String> launchArgs;
  final String? notes;
  final SaveProfile saveProfile;
  final GameStatus status;

  /// Сколько занимает установленная игра.
  final int sizeBytes;

  /// Почему игра в [GameStatus.error]. Пишется только вместе с этим
  /// статусом, потому и лежит рядом с ним, а не в части загрузки: ошибкой
  /// кончается не одна только загрузка.
  final String? lastError;

  /// Обложка, кадры, описание, оценка и откуда они.
  final GameDetails details;

  /// Что предложила база путей сохранений.
  final SaveDiscovery saveDiscovery;

  /// Откуда игра качается и как её найти в движке.
  final DownloadLink download;

  /// Сколько и когда в неё играли.
  final PlayStats play;

  bool get isInstalled =>
      status == GameStatus.installed || status == GameStatus.running;

  bool get canLaunch => executablePath != null && executablePath!.isNotEmpty;

  Game copyWith({
    String? title,
    Object? installDir = _u,
    Object? executablePath = _u,
    List<String>? launchArgs,
    Object? notes = _u,
    SaveProfile? saveProfile,
    GameStatus? status,
    int? sizeBytes,
    Object? lastError = _u,
    GameDetails? details,
    SaveDiscovery? saveDiscovery,
    DownloadLink? download,
    PlayStats? play,
  }) => Game(
    id: id,
    title: title ?? this.title,
    addedAt: addedAt,
    installDir: installDir == _u ? this.installDir : installDir as String?,
    executablePath: executablePath == _u
        ? this.executablePath
        : executablePath as String?,
    launchArgs: launchArgs ?? this.launchArgs,
    notes: notes == _u ? this.notes : notes as String?,
    saveProfile: saveProfile ?? this.saveProfile,
    status: status ?? this.status,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    lastError: lastError == _u ? this.lastError : lastError as String?,
    details: details ?? this.details,
    saveDiscovery: saveDiscovery ?? this.saveDiscovery,
    download: download ?? this.download,
    play: play ?? this.play,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'addedAt': addedAt.toIso8601String(),
    if (installDir != null) 'installDir': installDir,
    if (executablePath != null) 'executablePath': executablePath,
    'launchArgs': launchArgs,
    if (notes != null) 'notes': notes,
    'saveProfile': saveProfile.toJson(),
    'status': status.name,
    'sizeBytes': sizeBytes,
    if (lastError != null) 'lastError': lastError,
    ...details.toJson(),
    ...saveDiscovery.toJson(),
    ...download.toJson(),
    ...play.toJson(),
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
      installDir: json['installDir'] as String?,
      executablePath: json['executablePath'] as String?,
      launchArgs: (json['launchArgs'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      notes: json['notes'] as String?,
      saveProfile: json['saveProfile'] == null
          ? const SaveProfile()
          : SaveProfile.fromJson(json['saveProfile'] as Map<String, dynamic>),
      status: status,
      sizeBytes: json['sizeBytes'] as int? ?? 0,
      lastError: json['lastError'] as String?,
      details: GameDetails.fromJson(json),
      saveDiscovery: SaveDiscovery.fromJson(json),
      download: DownloadLink.fromJson(json),
      play: PlayStats.fromJson(json),
    );
  }

  static const _u = Object();

  @override
  List<Object?> get props => [
    id,
    title,
    addedAt,
    installDir,
    executablePath,
    launchArgs,
    notes,
    saveProfile,
    status,
    sizeBytes,
    lastError,
    details,
    saveDiscovery,
    download,
    play,
  ];
}
