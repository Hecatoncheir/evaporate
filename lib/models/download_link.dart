import 'package:equatable/equatable.dart';

import 'game_source.dart';

/// Откуда игра качается и как её найти в движке загрузок.
///
/// Одним значением, потому что правят его одни и те же события — поставили
/// в очередь, движок узнал infohash, перезапуск дал задаче новый id, — и
/// ни одно из них не имеет права задеть обложку или наигранное время.
class DownloadLink extends Equatable {
  const DownloadLink({this.source, this.downloadTaskId, this.infoHash});

  final GameSource? source;

  /// Идентификатор задачи в движке загрузок, пока она жива.
  final String? downloadTaskId;

  /// Infohash торрента — устойчивая связь с задачей движка: её
  /// идентификатор живёт только до перезапуска, infohash не меняется никогда.
  final String? infoHash;

  DownloadLink copyWith({
    Object? source = _u,
    Object? downloadTaskId = _u,
    Object? infoHash = _u,
  }) => DownloadLink(
    source: source == _u ? this.source : source as GameSource?,
    downloadTaskId: downloadTaskId == _u
        ? this.downloadTaskId
        : downloadTaskId as String?,
    infoHash: infoHash == _u ? this.infoHash : infoHash as String?,
  );

  /// Ключи прежние и лежат в общей записи игры: `library.json` разбор
  /// модели на части не трогает.
  Map<String, dynamic> toJson() => {
    if (source != null) 'source': source!.toJson(),
    if (downloadTaskId != null) 'downloadTaskId': downloadTaskId,
    if (infoHash != null) 'infoHash': infoHash,
  };

  factory DownloadLink.fromJson(Map<String, dynamic> json) => DownloadLink(
    source: json['source'] == null
        ? null
        : GameSource.fromJson(json['source'] as Map<String, dynamic>),
    // downloadGid — имя времён aria2, у которого идентификатор задачи
    // назывался gid. Библиотеки, записанные до переименования, несут его,
    // и без этой ветки загрузка потеряла бы связь со своей игрой.
    downloadTaskId: (json['downloadTaskId'] ?? json['downloadGid']) as String?,
    infoHash: json['infoHash'] as String?,
  );

  static const _u = Object();

  @override
  List<Object?> get props => [source, downloadTaskId, infoHash];
}
