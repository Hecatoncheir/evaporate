import 'package:equatable/equatable.dart';

enum GameSourceKind { magnet, torrentFile, localFolder }

/// Откуда игра берётся. Приложение не содержит каталога контента —
/// источник всегда задаёт пользователь.
class GameSource extends Equatable {
  const GameSource({required this.kind, required this.value});

  final GameSourceKind kind;

  /// magnet-ссылка, путь к .torrent, либо путь к уже готовой папке.
  final String value;

  /// Для журналов. В интерфейсе источник называют переводимыми ключами.
  String get logLabel => switch (kind) {
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

  @override
  List<Object?> get props => [kind, value];
}
