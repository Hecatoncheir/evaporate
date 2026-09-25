import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../art/key_art.dart';
import '../data/sample_data.dart';
import '../friends/friends_data.dart';
import '../profile/profile_data.dart';

/// Идущая игра: что запущено, сколько идёт и где вы сейчас. Одна на окно —
/// её читают герой, полоса карточки игры и оверлей, поэтому «1 ч 04 мин»,
/// «Глава 5» и «144 к/с» нигде не пишутся вторым числом.
@immutable
class EvSession {
  const EvSession({
    required this.game,
    required this.elapsed,
    required this.chapter,
    required this.place,
    required this.pid,
    required this.fps,
    required this.lowFps,
    required this.vramGb,
    required this.gpuC,
    required this.cpu,
    required this.earned,
  });

  final SampleGame game;

  /// Сколько идёт сессия.
  final Duration elapsed;

  /// «Глава 5» и «Кузня Сумерек».
  final String chapter;
  final String place;

  final int pid;

  /// Кадры в секунду сейчас и в 1 % самых медленных кадров.
  final int fps;
  final int lowFps;

  /// Видеопамять, ГБ; температура видеокарты, °C; загрузка процессора, %.
  final double vramGb;
  final int gpuC;
  final int cpu;

  /// Достижение, полученное в этой сессии, — то же, что первым стоит
  /// в профиле.
  final EvEarned earned;

  /// «01:04:12» — таймер в статусе «Идёт игра».
  String get clock {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(elapsed.inHours)}:${two(elapsed.inMinutes % 60)}:'
        '${two(elapsed.inSeconds % 60)}';
  }

  /// «1 ч 04 мин».
  String get length =>
      '${elapsed.inHours} ч ${(elapsed.inMinutes % 60).toString().padLeft(2, '0')} мин';

  /// «Глава 5 · Кузня Сумерек».
  String get where => '$chapter · $place';

  /// Что написать у друга в оверлее: кто в той же главе — так и сказано,
  /// остальные — во что играют или просто «в сети».
  String lineOf(EvPerson person) =>
      person.game == game && (person.session?.endsWith(chapter) ?? false)
      ? 'та же глава'
      : person.shortLine;
}

/// Минута кадров в секунду: 64 отсчёта, новый — раз в 900 мс.
///
/// Последний отсчёт — те же кадры, что в чипе героя: в прототипе история
/// начиналась со случайного числа, и крупная цифра над графиком расходилась
/// с «144 к/с» в герое.
class EvFrameSeries {
  EvFrameSeries(int fps, {int seed = 144}) : _rng = EvArtRandom(seed) {
    for (var i = 0; i < length; i++) {
      _history.add(138 + math.sin(i / 4) * 6 + _rng.next() * 9);
    }
    _history[length - 1] = fps.toDouble();
  }

  static const length = 64;

  final EvArtRandom _rng;
  final _history = <double>[];

  List<double> get history => List.unmodifiable(_history);

  /// Кадры в секунду сейчас.
  int get fps => _history.last.round();

  /// Время кадра: «6.9 мс».
  String get frame => '${(1000 / fps).toStringAsFixed(1)} мс';

  /// Шаг случайного блуждания, как в прототипе: ±5,5 кадра, 102…162.
  void advance() {
    _history
      ..add((_history.last + (_rng.next() - .5) * 11).clamp(102, 162))
      ..removeAt(0);
  }
}
