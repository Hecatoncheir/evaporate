import 'dart:math' as math;

import '../art/key_art.dart';
import '../friends/friends_data.dart';
import '../profile/friend_profile_data.dart';
import '../profile/profile_data.dart';
import '../widgets/ev_game_card.dart';
import 'sample_data.dart';
import 'sample_friends.dart';

// Страницы друзей. Два состояния написаны руками, как `FP` в прототипе:
// Антон открыт полностью, Игорь скрыл часы, достижения и игру. У остальных
// десяти страница выводится из их же номера — `fpData`, тот же генератор
// и тот же порядок вызовов, — а не копируется с Антона.

SampleGame _game(String title) =>
    sampleLibrary.firstWhere((g) => g.title == title);

final _anton = EvFriendProfile(
  person: samplePeople[0],
  since: 'в друзьях с марта 2025',
  shows: EvShare.values.toSet(),
  hours: 2140,
  achievements: (96, 240),
  year: EvPlayYear.friend(0, samplePeople[0].initials),
  common: [
    EvCommonGame(_game('Пепельный Предел'), 412),
    EvCommonGame(_game('Красный Меридиан'), 88),
    EvCommonGame(_game('Волчья Тропа'), 240),
    EvCommonGame(_game('Глубина 9'), 121),
    EvCommonGame(_game('Грозовой Фронт'), 36),
  ],
  // Только то, чего нет у вас: в карточках этих игр — неполученные.
  only: [
    (_game('Пепельный Предел'), 4),
    (_game('Глубина 9'), 3),
    (_game('Волчья Тропа'), 4),
  ],
);

final _igor = EvFriendProfile(
  person: samplePeople[6],
  since: 'в друзьях с ноября 2024',
  shows: {EvShare.seeding, EvShare.byCode},
  common: [
    EvCommonGame(_game('Пепельный Предел'), null),
    EvCommonGame(_game('Лунная Колея'), null),
    EvCommonGame(_game('Стеклянный Сад'), null),
  ],
);

/// Страница друга без своих данных. Первые два числа генератора ушли
/// на раздачу между вами (`EvTraffic` у друга), дальше — часы, достижения
/// и его часы в общих играх.
EvFriendProfile _derived(int i) {
  final p = samplePeople[i];
  final r = EvArtRandom(i * 7919 + 13)
    ..next()
    ..next();
  final rest = 400 + (r.next() * 1600).round();
  final unlocked = 20 + (r.next() * 90).round();
  final pool = sampleLibrary
      .where((g) => g.state == EvGameState.ready)
      .take(math.min(5, p.common));
  final common = [
    for (final g in pool)
      EvCommonGame(
        g,
        math.max(4, (g.played.inHours * (.4 + r.next() * 1.6)).round()),
      ),
  ];
  return EvFriendProfile(
    person: p,
    since: 'в друзьях с 2025 года',
    shows: EvShare.values.toSet(),
    // Часы за всё время — общие игры и всё остальное: иначе общие
    // могли бы оказаться больше, чем он наиграл вообще.
    hours: common.fold(0, (s, g) => s + g.his!) + rest,
    achievements: (unlocked, 240),
    year: EvPlayYear.friend(i, p.initials),
    common: common,
  );
}

/// Страница друга — для любого из двенадцати.
EvFriendProfile sampleFriendProfile(EvPerson person) {
  final i = samplePeople.indexOf(person);
  return switch (i) {
    0 => _anton,
    6 => _igor,
    _ => _derived(i),
  };
}
