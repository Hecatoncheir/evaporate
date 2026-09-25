import 'dart:convert';
import 'dart:io';

import 'package:evaporate/models/game.dart';

import '../art/key_art.dart';
import '../library/hero_state.dart';
import '../util/units.dart';
import '../widgets/ev_game_card.dart';
import 'sample_data.dart';

// Спайк «как есть»: единственная правка прототипа — откуда берутся игры.
// Библиотека читается из настоящего library.json моделью приложения и
// переводится в SampleGame прототипа. Обложки прототип рисует сам
// (EvCover/key_art), поэтому палитра и зерно выводятся из id игры, а
// настоящие картинки на экран не попадают.

/// Настоящая библиотека в словаре прототипа. Не задана — прототип
/// показывает свои примеры.
EvRealLibrary? evRealLibrary;

/// Игры для окна: настоящие, если прочитаны, иначе примеры прототипа.
List<SampleGame> get evLibrary => evRealLibrary?.games ?? sampleLibrary;

SampleGame get evHero => evRealLibrary?.hero ?? sampleHero;

List<SampleGame> get evSessions => evRealLibrary?.sessions ?? sampleSessions;

class EvRealLibrary {
  EvRealLibrary._(this.games, this.hero, this.sessions, this.heroContent,
      this.coversFound);

  final List<SampleGame> games;
  final SampleGame hero;
  final List<SampleGame> sessions;

  /// Герой в состоянии «Установлена» — про настоящую игру.
  final EvHeroContent heroContent;

  /// Сколько обложек нашлось в копии (они не рисуются — см. выше).
  final int coversFound;

  static const _palettes = [
    EvCoverPalette.ash,
    EvCoverPalette.deepSea,
    EvCoverPalette.neon,
    EvCoverPalette.lunar,
    EvCoverPalette.crimson,
    EvCoverPalette.glass,
    EvCoverPalette.wolf,
    EvCoverPalette.orbit,
    EvCoverPalette.threshold,
    EvCoverPalette.storm,
  ];

  /// Читает копию `library.json` из [dataDir]; пути обложек переводятся
  /// с настоящей папки приложения на копию рядом с файлом.
  static EvRealLibrary load(String dataDir, {DateTime? now}) {
    final raw = jsonDecode(
      File('$dataDir/library.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final list = (raw['games'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Game.fromJson)
        .toList();
    var covers = 0;
    for (final g in list) {
      final path = g.details.coverPath;
      if (path == null) continue;
      final name = path.split(RegExp(r'[\\/]')).last;
      if (File('$dataDir/covers/$name').existsSync()) covers++;
    }
    final clock = now ?? DateTime.now();
    final games = [for (final g in list) _toSample(g, clock)];
    final byGame = {for (var i = 0; i < list.length; i++) list[i]: games[i]};
    final played = [
      for (final g in list)
        if (g.play.lastPlayed != null) g,
    ]..sort((a, b) => b.play.lastPlayed!.compareTo(a.play.lastPlayed!));
    final heroGame = played.firstOrNull ??
        list.firstWhere(
          (g) => g.status == GameStatus.installed,
          orElse: () => list.first,
        );
    final hero = byGame[heroGame]!;
    final sessions = [
      for (final g in played)
        if (g != heroGame) byGame[g]!,
    ];
    return EvRealLibrary._(
      games,
      hero,
      sessions,
      _heroContent(heroGame, hero),
      covers,
    );
  }

  static EvHeroContent _heroContent(Game game, SampleGame hero) =>
      EvHeroContent(
        eyebrow: 'Продолжить · сыграно ${formatPlayed(hero.played)}',
        blurb: hero.blurb,
        chips: [
          (_stateLabel(game.status), true),
          if (hero.size.isNotEmpty) (hero.size, false),
          if (game.details.rating?.metacritic case final m?)
            ('Metacritic $m', false),
        ],
      );

  static String _stateLabel(GameStatus s) => switch (s) {
    GameStatus.installed || GameStatus.running => 'Установлена',
    GameStatus.downloading => 'Качается',
    GameStatus.paused => 'На паузе',
    GameStatus.notInstalled => 'Не установлена',
    GameStatus.error => 'Ошибка',
  };

  static SampleGame _toSample(Game g, DateTime now) {
    final hash = _stableHash(g.id);
    return SampleGame(
      g.title,
      '',
      _palettes[hash % _palettes.length],
      hash % 10000,
      version: '',
      size: _size(g.sizeBytes),
      blurb: g.details.description ?? '',
      state: switch (g.status) {
        GameStatus.installed || GameStatus.running => EvGameState.ready,
        GameStatus.downloading => EvGameState.downloading,
        _ => EvGameState.queued,
      },
      progress: g.status == GameStatus.downloading ? 0 : null,
      played: g.play.playtime,
      lastPlayed: switch (g.play.lastPlayed) {
        final t? => _when(t, now),
        null => null,
      },
      game: g,
    );
  }

  /// Хеш без зависимости от запуска: `String.hashCode` меняется между
  /// процессами, а обложка должна быть одной и той же.
  static int _stableHash(String s) {
    var h = 0x811C9DC5;
    for (final c in s.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0x7FFFFFFF;
    }
    return h;
  }

  static String _size(int bytes) =>
      bytes <= 0 ? '' : '${(bytes / 1e9).toStringAsFixed(1)} ГБ';

  static String _when(DateTime t, DateTime now) {
    final day = DateTime(t.year, t.month, t.day);
    final today = DateTime(now.year, now.month, now.day);
    final hm =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final days = today.difference(day).inDays;
    return switch (days) {
      0 => 'сегодня в $hm',
      1 => 'вчера в $hm',
      _ => '$days дн. назад',
    };
  }
}
