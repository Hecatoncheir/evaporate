import 'package:flutter/foundation.dart';

import '../data/game_facts.dart';
import '../data/sample_data.dart';
import '../data/sample_downloads.dart';
import '../data/sample_friends.dart';
import '../downloads/download_data.dart';
import '../widgets/ev_icon.dart';

/// Точка сохранения: где остановились, когда, сколько весит и ушла ли
/// в облако. Одна и та же в герое второго запуска и в карточке игры.
@immutable
class EvSaveSpot {
  const EvSaveSpot({
    required this.game,
    required this.where,
    required this.ago,
    required this.size,
    this.uploaded = true,
  });

  final SampleGame game;

  /// «02:14 · Глава 5, Кузня Сумерек» — время в игре и место.
  final String where;

  /// «41 минуту назад».
  final String ago;

  /// «148 МБ».
  final String size;

  final bool uploaded;
}

/// Дайджест во втором запуске: открыт или свёрнут в плашку. Вне второго
/// запуска его нет вовсе — это решает состояние героя, а не он сам.
enum EvDigestState { open, folded }

/// Чем окрашено событие дайджеста. Цвет — причина, а не громкость.
enum EvDigestTone { ok, hot, arc, warn }

/// Куда ведёт единственное действие события.
enum EvDigestTarget { downloads, heroCard, friend, gameCard }

/// Событие «Пока вас не было»: одна строка, одна подпись и не больше
/// одного действия.
@immutable
class EvDigestEvent {
  const EvDigestEvent({
    required this.tone,
    required this.icon,
    required this.title,
    required this.detail,
    this.action,
    this.target,
    this.game,
  });

  final EvDigestTone tone;
  final String icon;
  final String title;
  final String detail;

  /// Подпись кнопки; `null` — событие просто сообщает.
  final String? action;

  final EvDigestTarget? target;

  /// Игра, к которой ведёт действие, — если ведёт к игре.
  final SampleGame? game;
}

SampleGame _game(String title) =>
    sampleLibrary.firstWhere((g) => g.title == title);

/// Где вы остановились в игре героя. Те же 148 МБ, что у верхней точки
/// ленты сохранений, и то же место — пятая глава, Кузня Сумерек.
final sampleReturnSpot = EvSaveSpot(
  game: sampleHero,
  where: '02:14 · Глава 5, Кузня Сумерек',
  ago: '41 минуту назад',
  size: '148 МБ',
);

/// Пять событий за ночь. Всё, что можно, — из окна: сколько докачалось,
/// кто что прошёл, рейтинг раздачи.
///
/// В прототипе первым стояло «Орбита 7 докачана · Установить», хотя
/// в загрузках она на 41 %, а «Установить» ставило другую игру — героя.
/// И «Грозовой фронт остановился · нет раздающих», хотя он давно
/// установлен и сам раздаёт. Здесь события говорят то же, что окно.
List<EvDigestEvent> sampleDigestEvents() {
  final orbita = sampleDownloadsFor(EvDownloadsState.active).torrents.first;
  final storm = _game('Грозовой Фронт');
  final ratio = EvGameFacts.of(storm).ratio;
  return [
    EvDigestEvent(
      tone: EvDigestTone.ok,
      icon: EvIcons.download,
      title: '«${orbita.game.title}» качалась всю ночь',
      detail:
          '${formatGb(orbita.parts.received)} из ${formatGb(orbita.parts.total)} '
          '· ${orbita.eta}',
      action: 'К загрузкам',
      target: EvDigestTarget.downloads,
    ),
    EvDigestEvent(
      tone: EvDigestTone.hot,
      icon: EvIcons.boost,
      title: 'Обновление ${sampleUpdate.bareVersion} установлено',
      detail: 'ночью · 1.8 ГБ · вылет на Кузне починен',
      action: 'Что нового',
      target: EvDigestTarget.heroCard,
      game: sampleHero,
    ),
    EvDigestEvent(
      tone: EvDigestTone.arc,
      icon: EvIcons.trophy,
      title: '${samplePeople.first.name} прошёл Кузню Сумерек',
      detail: '3 часа назад · вы на той же главе',
      action: 'Посмотреть',
      target: EvDigestTarget.friend,
    ),
    const EvDigestEvent(
      tone: EvDigestTone.ok,
      icon: EvIcons.cloud,
      title: '2 сохранения выгружены',
      detail: 'конфликтов нет',
    ),
    EvDigestEvent(
      tone: EvDigestTone.warn,
      icon: EvIcons.seed,
      title: '«${storm.title}» раздаётся впустую',
      detail:
          'никто не качает 6 часов · рейтинг '
          '${ratio.toStringAsFixed(2).replaceAll('.', ',')}',
      action: 'Показать',
      target: EvDigestTarget.gameCard,
      game: storm,
    ),
  ];
}
