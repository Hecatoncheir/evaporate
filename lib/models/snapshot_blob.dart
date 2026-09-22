import 'package:equatable/equatable.dart';

/// Один файл снимка: имя внутри пакета и содержимое, найденное по хешу.
///
/// [size] — размер исходного файла, не сжатого: он идёт в манифест пакета и
/// должен совпасть с тем, что увидит другое устройство.
class SnapshotBlob extends Equatable {
  const SnapshotBlob({
    required this.name,
    required this.hash,
    required this.size,
    this.modified,
  });

  /// Имя внутри `.evsave`: `data/<ruleId>/<путь внутри правила>`.
  final String name;

  /// sha256 содержимого. Он же адрес файла в хранилище.
  final String hash;
  final int size;

  /// Когда файл менялся в последний раз, на момент снятия.
  ///
  /// Восстановление ставит его разложенному файлу. Без этого после любой
  /// раскладки всё было датировано «сейчас»: проверка «здесь новее» при
  /// переносе считала здешние сейвы свежее любого пакета, а игры, которые
  /// выбирают «Продолжить» по времени файла, путали слоты. `null` — у
  /// снимков, снятых до того, как время стали хранить.
  final DateTime? modified;

  /// Время — миллисекундами эпохи: оно уезжает на другие устройства, а у
  /// эпохи, в отличие от записи даты, нет часового пояса.
  Map<String, dynamic> toJson() => {
    'name': name,
    'hash': hash,
    'size': size,
    if (modified != null) 'modified': modified!.millisecondsSinceEpoch,
  };

  factory SnapshotBlob.fromJson(Map<String, dynamic> json) => SnapshotBlob(
    name: json['name'] as String,
    hash: json['hash'] as String,
    size: json['size'] as int? ?? 0,
    modified: momentOf(json['modified']),
  );

  /// Миллисекунды эпохи из записи; что угодно другое — «не знаем».
  static DateTime? momentOf(Object? raw) =>
      raw is int ? DateTime.fromMillisecondsSinceEpoch(raw) : null;

  @override
  List<Object?> get props => [name, hash, size, modified];
}
