import 'package:equatable/equatable.dart';

import 'save_profile.dart';
import 'snapshot_blob.dart';

/// Снимок сохранений: zip-архив в хранилище приложения плюс метаданные.
/// Тот же формат используется для экспорта на другое устройство (.evsave).
const _unset = Object();

class SaveSnapshot extends Equatable {
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
    this.blobs = const [],
  });

  final String id;
  final String gameId;
  final String gameTitle;
  final DateTime createdAt;
  final String deviceName;
  final String platform;
  final int sizeBytes;

  /// Путь к собственному архиву снимка.
  ///
  /// Пуст у снимков, которые лежат в хранилище по содержимому: у них файла
  /// нет вовсе, а пакет собирается из [blobs] по требованию. Непустым он
  /// остаётся у снятых до появления хранилища — их не переписываем, они
  /// уходят сами по мере ротации.
  final String archivePath;

  /// Файлы снимка, найденные по содержимому. Пусто у старых снимков.
  final List<SnapshotBlob> blobs;

  /// Хранится ли снимок по содержимому, а не своим архивом.
  bool get isDeduplicated => blobs.isNotEmpty;

  /// Правила путей на момент снимка — нужны, чтобы разложить файлы обратно
  /// даже если игра пришла на новое устройство вместе с сейвом.
  final List<SavePathRule> rules;
  final Duration playtime;
  final String? note;
  final int fileCount;
  final SnapshotOrigin origin;

  SaveSnapshot copyWith({
    String? archivePath,
    // Заметку надо уметь и стереть, а `null` в обычном параметре значит
    // «не трогать»: без метки-пустышки снять её было бы нечем.
    Object? note = _unset,
    List<SnapshotBlob>? blobs,
  }) => SaveSnapshot(
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
    note: note == _unset ? this.note : note as String?,
    fileCount: fileCount,
    origin: origin,
    blobs: blobs ?? this.blobs,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'gameId': gameId,
    'gameTitle': gameTitle,
    'createdAt': writeMoment(createdAt),
    'deviceName': deviceName,
    'platform': platform,
    'sizeBytes': sizeBytes,
    'archivePath': archivePath,
    'rules': rules.map((r) => r.toJson()).toList(),
    'playtimeSeconds': playtime.inSeconds,
    if (note != null) 'note': note,
    'fileCount': fileCount,
    'origin': origin.name,
    if (blobs.isNotEmpty) 'blobs': blobs.map((blob) => blob.toJson()).toList(),
  };

  factory SaveSnapshot.fromJson(Map<String, dynamic> json) => SaveSnapshot(
    id: json['id'] as String,
    gameId: json['gameId'] as String,
    gameTitle: json['gameTitle'] as String? ?? '',
    createdAt: readMoment(json['createdAt']),
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
    blobs: (json['blobs'] as List<dynamic>? ?? const [])
        .map((e) => SnapshotBlob.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  /// Манифест внутри архива — то, что читает другое устройство при импорте.
  Map<String, dynamic> toManifest() => {
    'format': manifestFormat,
    'id': id,
    'gameId': gameId,
    'gameTitle': gameTitle,
    'createdAt': writeMoment(createdAt),
    'deviceName': deviceName,
    'platform': platform,
    'playtimeSeconds': playtime.inSeconds,
    'fileCount': fileCount,
    'sizeBytes': sizeBytes,
    if (note != null) 'note': note,
    'rules': rules.map((r) => r.toJson()).toList(),
    if (blobs.any((blob) => blob.modified != null))
      manifestModifiedKey: {
        for (final blob in blobs)
          if (blob.modified != null)
            blob.name: blob.modified!.millisecondsSinceEpoch,
      },
  };

  /// Время изменения файлов пакета: имя записи → миллисекунды эпохи.
  ///
  /// В манифесте, а не в самих записях zip, хотя поле для времени там есть:
  /// оно хранит местное время без пояса с точностью до двух секунд, то есть
  /// переносит ровно ту ошибку, от которой [writeMoment] уводит дату снимка.
  /// Ключ необязательный: сборки, которые о нём не знают, его пропускают, а
  /// пакет без него раскладывается как раньше. Версия формата поэтому не
  /// меняется.
  static const manifestModifiedKey = 'modified';

  /// Читает [manifestModifiedKey]; нечитаемые записи пропускаются.
  static Map<String, DateTime> modifiedOf(Map<String, dynamic>? manifest) {
    final raw = manifest?[manifestModifiedKey];
    if (raw is! Map) return const {};
    return {
      for (final MapEntry(:key, :value) in raw.entries)
        if (key is String && SnapshotBlob.momentOf(value) != null)
          key: SnapshotBlob.momentOf(value)!,
    };
  }

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

  /// Момент снятия — в UTC, со смещением в записи.
  ///
  /// Прежде писалось местное время без смещения, и другое устройство
  /// читало его как своё местное: снимок из UTC+3 в 10:00 на машине в UTC+0
  /// считался снятым в 10:00 по Гринвичу, на три часа позже правды, и
  /// проверка «здесь новее» при переносе ошибалась ровно на разницу поясов
  /// — в одну сторону затирая прогресс, в другую давая ложные конфликты.
  /// `Z` понимают и старые сборки: `DateTime.parse` читал его всегда, так
  /// что версия формата от этого не меняется. Пакеты, записанные раньше,
  /// по-прежнему читаются местным временем читающего — смещения в них нет,
  /// и восстановить его неоткуда.
  static String writeMoment(DateTime moment) =>
      moment.toUtc().toIso8601String();

  /// Читает [writeMoment] и прежние записи без смещения.
  ///
  /// Нечитаемая дата — эпоха, а не «сейчас»: пакет с «сейчас» выглядел бы
  /// самым свежим из всех и проходил бы проверку «здесь новее» при
  /// переносе, затирая то, что новее на самом деле. В местное время
  /// переводится сразу, чтобы снимки сравнивались и показывались одинаково,
  /// откуда бы ни пришли.
  static DateTime readMoment(Object? raw) =>
      (raw is String ? DateTime.tryParse(raw)?.toLocal() : null) ??
      DateTime.fromMillisecondsSinceEpoch(0);
  static const dataPrefix = 'data';
  static const fileExtension = '.evsave';

  @override
  List<Object?> get props => [
    id,
    gameId,
    gameTitle,
    createdAt,
    deviceName,
    platform,
    sizeBytes,
    archivePath,
    blobs,
    rules,
    playtime,
    note,
    fileCount,
    origin,
  ];
}

enum SnapshotOrigin { manual, autoOnExit, autoOnLaunch, imported, preRestore }
