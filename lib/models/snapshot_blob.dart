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
  });

  /// Имя внутри `.evsave`: `data/<ruleId>/<путь внутри правила>`.
  final String name;

  /// sha256 содержимого. Он же адрес файла в хранилище.
  final String hash;
  final int size;

  Map<String, dynamic> toJson() => {'name': name, 'hash': hash, 'size': size};

  factory SnapshotBlob.fromJson(Map<String, dynamic> json) => SnapshotBlob(
    name: json['name'] as String,
    hash: json['hash'] as String,
    size: json['size'] as int? ?? 0,
  );

  @override
  List<Object?> get props => [name, hash, size];
}
