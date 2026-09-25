import 'package:flutter/foundation.dart';

import '../data/sample_data.dart';
import '../design/tokens.dart';

/// Состояние раздела «Друзья». «Нет сети» здесь нет: это состояние окна,
/// его включают в библиотеке или в загрузках, и раздел читает его сам.
enum EvFriendsState {
  normal('Без заявок', 'шесть в сети, трое в игре'),
  invite('Заявка в друзья', 'кто-то нашёл вас по коду');

  const EvFriendsState(this.label, this.hint);

  final String label;
  final String hint;
}

/// Где сейчас человек.
enum EvPersonStatus {
  /// В игре — и видно, в какой.
  playing,

  /// В сети, но не играет.
  online,

  /// Не в сети.
  offline,
}

/// Друг.
@immutable
class EvPerson {
  const EvPerson({
    required this.initials,
    required this.name,
    required this.tint,
    required this.common,
    required this.traffic,
    this.female = false,
    this.status = EvPersonStatus.offline,
    this.game,
    this.session,
    this.was,
  });

  final String initials;
  final String name;
  final EvAvatarTint tint;

  /// Сколько игр у вас общих. Больше библиотеки быть не может.
  final int common;

  /// Сколько вы раздали друг другу за всё время.
  final EvTraffic traffic;

  /// Род — для «раздала вам», «она не показывает», «это её выбор».
  final bool female;

  /// Имя без инициала фамилии: «Антон».
  String get firstName => name.split(' ').first;

  /// «он» / «она».
  String get he => female ? 'она' : 'он';

  /// «его» / «её».
  String get his => female ? 'её' : 'его';

  /// После предлога: «от него» / «от неё».
  String get fromHim => female ? 'неё' : 'него';

  /// «ему» / «ей».
  String get him => female ? 'ей' : 'ему';

  /// Прошедшее время: «раздал» → «раздала».
  String past(String verb) => female ? '$verbа' : verb;

  final EvPersonStatus status;

  /// Во что играет — если играет.
  final SampleGame? game;

  /// «2 ч 14 мин · Глава 5».
  final String? session;

  /// Когда был в сети: «был вчера в 22:10».
  final String? was;

  /// Короткая строка для правой колонки библиотеки: только игра.
  String get shortLine => switch (status) {
    EvPersonStatus.playing => game!.title,
    EvPersonStatus.online => 'в сети',
    EvPersonStatus.offline => was ?? 'не в сети',
  };

  /// Строка состояния в списке. Состояние приходит отдельно: без сети
  /// окно показывает всех офлайн, и подпись должна говорить то же, что
  /// точка на аватаре, — иначе они разойдутся.
  String lineFor(EvPersonStatus shown) => switch (shown) {
    EvPersonStatus.playing => 'в игре · ${game!.title}',
    EvPersonStatus.online => 'в сети',
    EvPersonStatus.offline => was ?? 'не в сети',
  };

  String get line => lineFor(status);
}

/// Раздача между вами и другом за всё время — в обе стороны.
@immutable
class EvTraffic {
  const EvTraffic({required this.toYouGb, required this.fromYouGb});

  /// Он вам, ГБ.
  final int toYouGb;

  /// Вы ему, ГБ.
  final int fromYouGb;

  /// Какая доля трафика между вами шла от него, 0…1.
  double get share => toYouGb / (toYouGb + fromYouGb);
}

/// Друг, который раздаёт вам одну из ваших загрузок.
@immutable
class EvSeeder {
  const EvSeeder({
    required this.person,
    required this.game,
    required this.rateKb,
    required this.ofKb,
  });

  final EvPerson person;

  /// Какую раздачу он отдаёт.
  final SampleGame game;

  /// Сколько даёт он, КБ/с.
  final int rateKb;

  /// Сколько идёт всего по этой раздаче, КБ/с. Берётся с экрана
  /// загрузок, поэтому доля не может разойтись с ним.
  final int ofKb;

  /// Доля 0…1.
  double get share => rateKb / ofKb;
}

/// Событие в ленте друзей.
@immutable
class EvFeedEntry {
  const EvFeedEntry({
    required this.person,
    required this.did,
    required this.what,
    required this.when,
    this.tail = '',
    this.bright = false,
  });

  final EvPerson person;

  /// Что сделал: «получил», «раздала вам».
  final String did;

  /// Предмет действия — он выделен.
  final String what;

  /// Остаток фразы: «в «Пепельном Пределе»», «за неделю».
  final String tail;

  /// «3 часа назад».
  final String when;

  /// Достижение — выделяется горячим, а не просто плотным.
  final bool bright;
}

/// Заявка в друзья.
@immutable
class EvInvite {
  const EvInvite({
    required this.initials,
    required this.name,
    required this.tint,
    required this.detail,
  });

  final String initials;
  final String name;
  final EvAvatarTint tint;

  /// «3 общие игры · нашёл вас по коду · 12 минут назад».
  final String detail;
}

/// Как ваша библиотека пересекается с библиотеками друзей. Три числа
/// делят её целиком, поэтому полоса под ними — их доли, а не четвёртое
/// число рядом.
@immutable
class EvSharedLibrary {
  const EvSharedLibrary({
    required this.everyone,
    required this.half,
    required this.onlyYou,
  });

  /// Есть у всех друзей.
  final int everyone;

  /// Есть у половины.
  final int half;

  /// Нет ни у кого из них.
  final int onlyYou;

  int get total => everyone + half + onlyYou;

  /// Сколько игр есть хотя бы у одного друга.
  int get shared => everyone + half;
}

/// Всё, что раздел показывает в одном состоянии.
@immutable
class EvFriends {
  const EvFriends({
    required this.people,
    required this.seeders,
    required this.feed,
    required this.library,
    this.invite,
    this.offline = false,
  });

  final List<EvPerson> people;

  /// Кто раздаёт вам прямо сейчас. Без сети — никто.
  final List<EvSeeder> seeders;

  final List<EvFeedEntry> feed;
  final EvSharedLibrary library;

  final EvInvite? invite;

  /// Сети нет: все офлайн, пиров от друзей нет.
  final bool offline;

  List<EvPerson> get playing => offline
      ? const []
      : [
          for (final p in people)
            if (p.status == EvPersonStatus.playing) p,
        ];

  int get online => offline
      ? 0
      : people.where((p) => p.status != EvPersonStatus.offline).length;

  /// Сколько вы отдали друзьям за всё время, ГБ, — сумма по каждому.
  int get givenGb => people.fold(0, (sum, p) => sum + p.traffic.fromYouGb);

  /// Сколько друзья дают прямо сейчас, КБ/с — сумма по раздающим.
  int get fromFriendsKb => seeders.fold(0, (sum, s) => sum + s.rateKb);

  /// Какая доля вашего приёма приходит от друзей, 0…1.
  double shareOf(int totalKb) => totalKb == 0 ? 0 : fromFriendsKb / totalKb;
}
