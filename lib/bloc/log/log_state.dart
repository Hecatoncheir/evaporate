part of 'log_bloc.dart';

/// Прочитанные строки журнала.
class LogState extends Equatable {
  const LogState({this.lines, this.busy = false});

  /// `null` — ещё не показывали. Пусто — показывали, и там пусто: это
  /// разные вещи, и карточка их различает.
  final List<String>? lines;

  final bool busy;

  LogState copyWith({List<String>? lines, bool? busy}) =>
      LogState(lines: lines ?? this.lines, busy: busy ?? this.busy);

  @override
  List<Object?> get props => [lines, busy];
}
