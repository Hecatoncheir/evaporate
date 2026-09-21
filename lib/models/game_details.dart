import 'package:equatable/equatable.dart';

import 'game_rating.dart';

/// Что об игре известно, кроме неё самой: обложка, кадры, описание, оценка
/// и то, откуда это взято.
///
/// Одним значением, а не семью полями в `Game`: приходит оно одним
/// поиском в Steam и одним же поиском обновляется. Разложенное по игре,
/// оно правилось бы тем же `copyWith`, что и статус загрузки, — и ничто
/// не мешало бы событию о загрузке задеть обложку.
///
/// Обложку человек может выбрать и сам, поэтому это не «данные Steam», а
/// подробности вообще: [steamAppId] лишь говорит, откуда они пришли,
/// если пришли оттуда.
class GameDetails extends Equatable {
  const GameDetails({
    this.coverPath,
    this.coverUrl,
    this.shotPaths = const [],
    this.description,
    this.rating,
    this.steamAppId,
    this.steamLookupAttempted = false,
  });

  final String? coverPath;

  /// Исходная ссылка Steam. UI использует сохранённый файл [coverPath].
  final String? coverUrl;

  /// Кадры из игры, сохранённые из Steam, — подложка под крупным кадром
  /// библиотеки. Пусто у всего, что со Steam не сошлось, и это обычное
  /// дело: у торрент-релиза без `appid` брать их неоткуда.
  ///
  /// Миниатюры, а не полные кадры: подложка размыта и затемнена, разницы
  /// не видно, а 1920×1080 разворачивается в памяти в восемь мегабайт
  /// против восьмисот килобайт у 600×338.
  final List<String> shotPaths;
  final String? description;

  /// Как игру оценили в Steam. `null` — не спрашивали либо не нашли.
  final GameRating? rating;

  /// Идентификатор в Steam — чтобы не искать игру повторно.
  final int? steamAppId;

  /// Попытка, а не только успех: автоматический запрос не повторяется
  /// после ошибки сети, отсутствия результата или перезапуска приложения.
  final bool steamLookupAttempted;

  GameDetails copyWith({
    Object? coverPath = _u,
    Object? coverUrl = _u,
    List<String>? shotPaths,
    Object? description = _u,
    Object? rating = _u,
    Object? steamAppId = _u,
    bool? steamLookupAttempted,
  }) => GameDetails(
    coverPath: coverPath == _u ? this.coverPath : coverPath as String?,
    coverUrl: coverUrl == _u ? this.coverUrl : coverUrl as String?,
    shotPaths: shotPaths ?? this.shotPaths,
    description: description == _u ? this.description : description as String?,
    rating: rating == _u ? this.rating : rating as GameRating?,
    steamAppId: steamAppId == _u ? this.steamAppId : steamAppId as int?,
    steamLookupAttempted: steamLookupAttempted ?? this.steamLookupAttempted,
  );

  /// Ключи прежние и лежат в общей записи игры, а не вложенным объектом:
  /// `library.json` у людей на дисках, и разбор модели на части его не
  /// касается.
  Map<String, dynamic> toJson() => {
    if (coverPath != null) 'coverPath': coverPath,
    if (coverUrl != null) 'coverUrl': coverUrl,
    if (shotPaths.isNotEmpty) 'shotPaths': shotPaths,
    if (description != null) 'description': description,
    if (rating != null) 'rating': rating!.toJson(),
    if (steamAppId != null) 'steamAppId': steamAppId,
    'steamLookupAttempted': steamLookupAttempted,
  };

  factory GameDetails.fromJson(Map<String, dynamic> json) => GameDetails(
    coverPath: json['coverPath'] as String?,
    coverUrl: json['coverUrl'] as String?,
    shotPaths: (json['shotPaths'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(),
    description: json['description'] as String?,
    rating: json['rating'] == null
        ? null
        : GameRating.fromJson(json['rating'] as Map<String, dynamic>),
    steamAppId: json['steamAppId'] as int?,
    // Записи до появления маркера: найденный `appid` и значит, что искали.
    steamLookupAttempted:
        json['steamLookupAttempted'] as bool? ?? json['steamAppId'] != null,
  );

  static const _u = Object();

  @override
  List<Object?> get props => [
    coverPath,
    coverUrl,
    shotPaths,
    description,
    rating,
    steamAppId,
    steamLookupAttempted,
  ];
}
