part of 'library_view_bloc.dart';

/// Отбор по названию и порядок показа.
///
/// Сперва то, что происходит прямо сейчас, потом недавно запущенное, потом
/// всё остальное по алфавиту: человек открывает библиотеку, чтобы
/// продолжить, а не чтобы читать список с начала.
List<Game> searchGames(List<Game> games, String query) {
  final needle = query.trim().toLowerCase();
  final filtered = needle.isEmpty
      ? [...games]
      : games
            .where((game) => game.title.toLowerCase().contains(needle))
            .toList();
  filtered.sort(_byActivityThenTitle);
  return filtered;
}

int _byActivityThenTitle(Game a, Game b) {
  final byActivity = _activityRank(a).compareTo(_activityRank(b));
  if (byActivity != 0) return byActivity;
  final aPlayed = a.lastPlayed;
  final bPlayed = b.lastPlayed;
  if (aPlayed != null && bPlayed != null) return bPlayed.compareTo(aPlayed);
  if (aPlayed != null) return -1;
  if (bPlayed != null) return 1;
  return a.title.toLowerCase().compareTo(b.title.toLowerCase());
}

int _activityRank(Game game) => switch (game.status) {
  GameStatus.running => 0,
  GameStatus.downloading => 1,
  GameStatus.paused => 2,
  GameStatus.error => 3,
  GameStatus.installed => 4,
  GameStatus.notInstalled => 5,
};
