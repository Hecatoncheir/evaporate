import 'package:equatable/equatable.dart';

/// Сколько в игру играли и когда в последний раз.
///
/// Пишет их один только выход из игры, и одним значением: правка, пришедшая
/// во время сеанса, — выбор исполняемого файла, найденная обложка, —
/// сеанс затереть не может.
class PlayStats extends Equatable {
  const PlayStats({this.playtime = Duration.zero, this.lastPlayed});

  final Duration playtime;
  final DateTime? lastPlayed;

  PlayStats copyWith({Duration? playtime, Object? lastPlayed = _u}) =>
      PlayStats(
        playtime: playtime ?? this.playtime,
        lastPlayed: lastPlayed == _u
            ? this.lastPlayed
            : lastPlayed as DateTime?,
      );

  /// Ключи прежние и лежат в общей записи игры: `library.json` разбор
  /// модели на части не трогает.
  Map<String, dynamic> toJson() => {
    'playtimeSeconds': playtime.inSeconds,
    if (lastPlayed != null) 'lastPlayed': lastPlayed!.toIso8601String(),
  };

  factory PlayStats.fromJson(Map<String, dynamic> json) => PlayStats(
    playtime: Duration(seconds: json['playtimeSeconds'] as int? ?? 0),
    lastPlayed: DateTime.tryParse(json['lastPlayed'] as String? ?? ''),
  );

  static const _u = Object();

  @override
  List<Object?> get props => [playtime, lastPlayed];
}
