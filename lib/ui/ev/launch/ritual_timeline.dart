import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import '../design/tokens.dart';

/// Тайминги ритуала запуска, от нажатия. Сняты с прототипа.
///
/// * 0 — затемнение проявляется за 300 мс, искры срываются вверх;
/// * 0…2600 — шесть стадий: кольцо, полоса и подписи идут линейно;
/// * 2600 — удар: вспышка гаснет за 500 мс, волна расходится за 900;
/// * 2600…3600 — ирис раскрывает окно из центра;
/// * 4020 — затемнение уходит за 300 мс.
///
/// Без ритуала затемнение с ядром и названием держится 900 мс и уходит.
abstract final class EvRitualTiming {
  /// Затемнение проявляется и уходит.
  static const fade = Duration(milliseconds: 300);

  /// От нажатия до удара.
  static const strike = EvMotion.ritual;

  static const flash = Duration(milliseconds: 500);
  static const shock = Duration(milliseconds: 900);
  static const iris = Duration(milliseconds: 1000);

  /// Когда затемнение начинает уходить: ирис раскрыт и 420 мс держится.
  static const full = Duration(milliseconds: 4020);

  /// Когда уходит затемнение без ритуала.
  static const brief = Duration(milliseconds: 900);

  /// Затемнение проявляется с `ease` из CSS, а уходит зеркально: переход
  /// от 1 к 0 в браузере — это 1 − ease(t), а не ease(1 − t).
  static const fadeIn = Curves.ease;
  static final fadeOut = Curves.ease.flipped;

  /// Дыхание шара: 1,5 с на вдох и выдох, ease-in-out на каждой половине.
  static const breathe = Duration(milliseconds: 1500);

  /// Пунктирные кольца: оборот по часовой за 18 с и против — за 26.
  static const innerTurn = Duration(seconds: 18);
  static const outerTurn = Duration(seconds: 26);
}

/// Кадр ритуала: всё, что меняется во времени, — функция от прошедшего
/// времени, а не от числа кадров. В прототипе ирис раскрывался на 2,2 %
/// за кадр и на 144 Гц проходил вдвое с лишним быстрее.
@immutable
class EvRitualFrame {
  const EvRitualFrame._({
    required this.progress,
    required this.flash,
    required this.shock,
    required this.iris,
  });

  factory EvRitualFrame.at(Duration elapsed) {
    final ms = elapsed.inMicroseconds / 1000;
    final strike = EvRitualTiming.strike.inMilliseconds;
    final progress = (ms / strike).clamp(0.0, 1.0);
    final since = ms - strike;
    if (since < 0) {
      return EvRitualFrame._(
        progress: progress,
        flash: 0,
        shock: null,
        iris: 0,
      );
    }
    final flashT = since / EvRitualTiming.flash.inMilliseconds;
    final shockT = since / EvRitualTiming.shock.inMilliseconds;
    return EvRitualFrame._(
      progress: progress,
      // @keyframes flash{0%{opacity:.9}100%{opacity:0}} · .5s ease-out
      flash: flashT >= 1 ? 0 : .9 * (1 - Curves.easeOut.transform(flashT)),
      // @keyframes shock · .9s var(--ease-out)
      shock: EvMotion.easeOut.transform(math.min(1.0, shockT)),
      // k += .022 за кадр при 60 Гц, пока k < 1.3: за секунду до 132 %
      iris: 1.32 * math.min(1.0, since / EvRitualTiming.iris.inMilliseconds),
    );
  }

  /// Кольцо, полоса и стадии: 0…1 за 2,6 с, линейно.
  final double progress;

  /// Непрозрачность белой вспышки поверх всего.
  final double flash;

  /// Ход ударной волны после кривой, 0…1; `null` — удара ещё не было.
  final double? shock;

  /// Радиус отверстия ириса в долях расстояния от центра окна до угла:
  /// 0 — пустота закрывает всё, от 1 — окно открыто целиком.
  final double iris;

  /// Удар был: вспышка, волна, ирис.
  bool get struck => shock != null;

  /// Номер стадии из [count]: floor(p·n), последняя держится до конца.
  int stage(int count) => math.min(count - 1, (progress * count).floor());

  /// Внешний диаметр волны в окне [window]: 20 px → 190 vmax.
  double shockDiameter(Size window) =>
      20 + (1.9 * window.longestSide - 20) * (shock ?? 0);

  /// Толщина кромки волны: 3 px → 0.
  double get shockWidth => 3 * (1 - (shock ?? 1));

  /// Непрозрачность волны: 1 → 0.
  double get shockOpacity => 1 - (shock ?? 1);
}

/// Дыхание шара ядра в момент [elapsed]: 0 — покой, 1 — вдох (масштаб
/// 1,11 и яркость +20 %). `@keyframes orbp{50%{…}}` с ease-in-out на
/// каждой половине.
double evOrbBreath(Duration elapsed) {
  final period = EvRitualTiming.breathe.inMicroseconds;
  final phase = (elapsed.inMicroseconds % period) / period;
  return phase < .5
      ? Curves.easeInOut.transform(phase * 2)
      : 1 - Curves.easeInOut.transform((phase - .5) * 2);
}
