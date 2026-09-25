import '../art/key_art.dart';
import '../friends/friends_data.dart';
import 'sample_friends.dart';
import '../widgets/ev_game_card.dart';
import 'sample_data.dart';

/// Часть игры на диске: озвучка, текстуры, саундтрек. Обязательную часть
/// снять нельзя.
class EvGamePart {
  const EvGamePart(
    this.name,
    this.size, {
    this.onDisk = false,
    this.required = false,
  });

  final String name;

  /// Размер, ГБ.
  final double size;

  final bool onDisk;
  final bool required;
}

/// Достижение: название и условие.
typedef EvAchievement = (String name, String rule);

/// То, что знает лаунчер и не знает магазин: часы, сессии, достижения,
/// состав на диске, раздача и друзья в этой игре.
///
/// Всё выводится из сида игры тем же генератором, что и обложка
/// (`rng32(seed + 77)` в прототипе), и в том же порядке вызовов, поэтому
/// числа в карточке те же, что в макете. Движка нет — когда он появится,
/// эти поля придут от него.
class EvGameFacts {
  EvGameFacts._({
    required this.hours,
    required this.total,
    required this.installed,
    required this.sessions,
    required this.unlocked,
    required this.lastMinutes,
    required this.lastAgo,
    required this.parts,
    required this.ratio,
    required this.peers,
    required this.friends,
  });

  factory EvGameFacts.of(SampleGame game) =>
      _cache[game] ??= EvGameFacts._compute(game);

  factory EvGameFacts._compute(SampleGame game) {
    final r = EvArtRandom(game.seed + 77);
    final hours = game.played.inHours;
    final total = double.tryParse(game.size.split(' ').first) ?? 10;
    final installed = game.state == EvGameState.ready;
    // Порядок обращений к генератору — как в прототипе: без часов
    // семь чисел на сессии не тратятся.
    final sessions = [
      for (var i = 0; i < 7; i++)
        hours > 0 ? (14 + r.next() * 118 * (i == 4 ? 1.35 : 1)).round() : 0,
    ];
    return EvGameFacts._(
      hours: hours,
      total: total,
      installed: installed,
      sessions: sessions,
      unlocked: hours > 0 ? 3 : 0,
      lastMinutes: hours > 0 ? 60 + (r.next() * 60).round() : 0,
      lastAgo: _lastAgo(game, hours > 0 ? (r.next() * 3).floor() : null),
      parts: [
        EvGamePart('Игра', total * .79, onDisk: installed, required: true),
        EvGamePart('Русская озвучка', total * .12, onDisk: installed),
        EvGamePart('Текстуры 4K', total * .09, onDisk: installed),
        EvGamePart('Английская озвучка', total * .115),
        EvGamePart('Саундтрек FLAC', total * .035),
      ],
      ratio: double.parse((0.4 + r.next() * 2.6).toStringAsFixed(2)),
      peers: 2 + (r.next() * 22).floor(),
      friends: sampleFriends.take(2 + (r.next() * 3).floor()).toList(),
    );
  }

  static final _cache = <SampleGame, EvGameFacts>{};

  /// Давность без точного времени — у игр, в которые играли раньше
  /// недавних. Самая свежая идёт первой.
  static const olderAgo = ['3 дня назад', 'неделю назад', 'месяц назад'];

  /// Когда закончилась последняя сессия. У недавних — их время из
  /// библиотеки; остальным — одна из [olderAgo] по сиду. В прототипе
  /// давность была случайной у всех: «Пепельный Предел», сыгранный
  /// 6 минут назад, в карточке значился «3 дня назад», а «Волчья Тропа»
  /// со вчерашнего вечера — «41 минуту назад».
  static String _lastAgo(SampleGame game, int? pick) =>
      game.lastPlayed ?? (pick == null ? '—' : olderAgo[pick]);

  /// Часов в игре всего; 0 — ещё не запускали.
  final int hours;

  /// Полный размер игры, ГБ.
  final double total;

  final bool installed;

  /// Минуты семи последних сессий, от понедельника.
  final List<int> sessions;

  /// Сколько достижений получено из [achievements].
  final int unlocked;

  /// Длительность последней сессии, мин.
  final int lastMinutes;

  /// Когда закончилась последняя сессия.
  final String lastAgo;

  final List<EvGamePart> parts;

  /// Рейтинг раздачи: отдано к скачанному.
  final double ratio;

  final int peers;

  /// Друзья, у которых эта игра.
  final List<EvPerson> friends;

  /// Отдано, ГБ.
  double get uploaded => total * ratio;

  /// Сколько лежит на диске, ГБ.
  double get onDisk =>
      parts.where((p) => p.onDisk).fold(0, (sum, p) => sum + p.size);

  /// Сколько ещё можно докачать, ГБ.
  double get toDownload =>
      parts.where((p) => !p.onDisk).fold(0, (sum, p) => sum + p.size);

  /// Достижения игры — пять, как в прототипе. Получены первые три, и
  /// «Собиратель» идёт сразу за ними: в прототипе он стоял третьим — то
  /// есть полученным — и тут же был «ближе всего» с 37 реликвиями из 60,
  /// хотя условие просило 40. «Без единой царапины» просило победить
  /// Кузнеца, а вы до сих пор в его Кузне.
  static const achievements = <EvAchievement>[
    ('Первый выдох', 'Пережить вступительную главу'),
    ('Тихий шаг', 'Пройти уровень, не подняв тревогу'),
    ('Без единой царапины', 'Пройти главу, не получив урона'),
    ('Собиратель', 'Найти все 60 реликвий'),
    ('Полный круг', 'Завершить все побочные линии'),
  ];

  /// Ближайшее к получению — «Собиратель»: сколько реликвий найдено
  /// и сколько их всего.
  static const collector = 3;
  static const relicsFound = 37;
  static const relicsTotal = 60;

  /// Дни недели под столбиками истории.
  static const days = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
}

/// Размер в гигабайтах, как в карточке: одна цифра после запятой.
String formatGb(double value) =>
    '${value.toStringAsFixed(1).replaceAll('.', ',')} ГБ';
