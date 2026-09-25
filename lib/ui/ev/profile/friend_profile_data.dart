import 'package:flutter/foundation.dart';

import '../data/game_facts.dart';
import '../data/sample_data.dart';
import '../friends/friends_data.dart';
import '../widgets/ev_icon.dart';
import 'profile_data.dart';

/// Общая игра: ваши часы и его. Его часы `null`, если он их скрыл.
@immutable
class EvCommonGame {
  const EvCommonGame(this.game, this.his);

  final SampleGame game;
  final int? his;

  /// Ваши часы — из библиотеки, те же, что в карточке игры.
  int get mine => game.played.inHours;
}

/// Достижение игры по номеру в [EvGameFacts.achievements].
typedef EvGameAchievement = (SampleGame game, int index);

/// Чужая страница. Она полезна сравнением, а не копией своей, и всё
/// скрытое на ней остаётся на месте — помеченным «скрыто».
///
/// Всё, что друг выключил, сюда просто не приходит: поля `null`. Какие
/// тумблеры выключены, говорит [shows], и страница проверяет, что одно
/// не разошлось с другим.
@immutable
class EvFriendProfile {
  EvFriendProfile({
    required this.person,
    required this.since,
    required this.shows,
    required this.common,
    this.hours,
    this.achievements,
    this.year,
    this.only = const [],
  }) : assert(
         (hours != null) == shows.contains(EvShare.hours) &&
             (achievements != null) == shows.contains(EvShare.hours) &&
             (year != null) == shows.contains(EvShare.hours),
         'часы, достижения и год скрываются одним тумблером',
       ),
       assert(
         common.every((g) => (g.his != null) == shows.contains(EvShare.hours)),
       );

  final EvPerson person;

  /// «в друзьях с марта 2025».
  final String since;

  /// Что он показывает друзьям.
  final Set<EvShare> shows;

  /// Общие игры, где больше всего часов, — не все.
  final List<EvCommonGame> common;

  /// Часов за всё время.
  final int? hours;

  /// Получено и всего в его библиотеке.
  final (int, int)? achievements;

  final EvPlayYear? year;

  /// Его достижения в общих играх, которых нет у вас.
  final List<EvGameAchievement> only;

  EvTraffic get traffic => person.traffic;

  /// Играет прямо сейчас — и показывает это.
  bool get playingShown =>
      person.status == EvPersonStatus.playing &&
      shows.contains(EvShare.playing);

  /// Состояние, которое видят друзья: скрытая игра выглядит как «в сети».
  EvPersonStatus get shownStatus =>
      person.status == EvPersonStatus.playing && !playingShown
      ? EvPersonStatus.online
      : person.status;

  /// Что скрыто — строки панели «Что скрыто»: подпись и знак. Поиск по коду другу не
  /// виден вовсе: он уже нашёл.
  List<(String, String)> get hidden => [
    if (!shows.contains(EvShare.playing)) ('Во что играет', EvIcons.play),
    if (!shows.contains(EvShare.hours)) ...[
      ('Часы и общее время', EvIcons.speed),
      ('Достижения', EvIcons.trophy),
    ],
    if (!shows.contains(EvShare.seeding)) ('Что раздаёт', EvIcons.seed),
  ];
}
