import 'dart:math' as math;
import 'dart:typed_data';

import '../art/key_art.dart';
import '../design/tokens.dart';
import '../launch/ritual_timeline.dart';
import 'synth.dart';

/// Класс голоса: сколько он может длиться и где живёт в спектре.
/// Интерфейс — 200 Гц – 4 кГц, всё ниже 120 Гц принадлежит ритуалу.
enum EvSoundClass {
  ui('Интерфейс', 'Наведение и нажатие · 200 Гц – 4 кГц · до 120 мс', 120),
  event('События', 'Готово, ошибка, испарение дайджеста · до 400 мс', 400),
  ritual('Удержание и ритуал', 'Всё ниже 120 Гц принадлежит запуску', 2600);

  const EvSoundClass(this.label, this.detail, this.limitMs);

  final String label;
  final String detail;

  /// Голос длиннее своего класса — ошибка, а не выразительность.
  final int limitMs;
}

/// Секунды из длительности.
double _s(Duration d) => d.inMicroseconds / 1e6;

/// Девять голосов. Ничего не сэмплировано: слои ниже — это и есть звук,
/// числа в таблице README — их аргументы.
enum EvVoice {
  tick('Касание', EvSoundClass.ui, 2200, 2200),
  tap('Нажатие', EvSoundClass.ui, 520, 300),
  swish('Смена раздела', EvSoundClass.ui, 420, 2300),
  charge('Удержание', EvSoundClass.ritual, 300, 2600),
  ok('Готово', EvSoundClass.event, 523, 784),
  warn('Внимание', EvSoundClass.event, 392, 294),
  err('Ошибка', EvSoundClass.event, 300, 150),
  evaporate('Испарение', EvSoundClass.event, 280, 5200),
  ritual('Ритуал запуска', EvSoundClass.ritual, 30, 5400);

  const EvVoice(this.label, this.soundClass, this.from, this.to);

  final String label;
  final EvSoundClass soundClass;

  /// Развёртка главного слоя, Гц.
  final double from;
  final double to;

  /// Из чего собран голос.
  List<EvLayer> get layers => switch (this) {
    tick => [
      EvNoiseLayer(dur: .03, gain: .035, filter: EvFilter.highpass, f0: from),
    ],
    tap => [
      EvToneLayer(dur: .07, gain: .09, f0: from, f1: to),
      const EvNoiseLayer(
        dur: .016,
        gain: .05,
        filter: EvFilter.highpass,
        f0: 3200,
      ),
    ],
    // В прототипе 190 мс — длиннее класса интерфейса.
    swish => [
      EvNoiseLayer(
        dur: .12,
        gain: .045,
        f0: from,
        f1: to,
        q: 1.2,
        linear: true,
      ),
    ],
    charge => _charge(from, to),
    ok => [
      EvToneLayer(dur: .1, gain: .07, wave: EvWave.triangle, f0: from),
      EvToneLayer(at: .07, dur: .16, gain: .06, wave: EvWave.triangle, f0: to),
    ],
    warn => [
      EvToneLayer(
        dur: .22,
        gain: .075,
        wave: EvWave.triangle,
        f0: from,
        f1: to,
      ),
    ],
    err => [
      EvToneLayer(dur: .3, gain: .085, wave: EvWave.triangle, f0: from, f1: to),
      const EvToneLayer(dur: .3, gain: .035, f0: 452, f1: 226, detune: 8),
      const EvNoiseLayer(
        dur: .05,
        gain: .05,
        filter: EvFilter.highpass,
        f0: 1400,
      ),
    ],
    evaporate => _evaporate(from, to),
    ritual => _ritual(from, to),
  };

  /// Буфер голоса; случайное в нём — из сида голоса, поэтому звучит
  /// всегда одинаково.
  Float32List render() => evRender(layers, seed: 97 + index);

  /// Сколько голос звучит — без 20 мс хвоста, мс.
  int get durationMs =>
      (layers.fold(0.0, (e, l) => math.max(e, l.end)) * 1000).round();

  /// Хвост после удара: у ритуала он гаснет вместе с волной, а в класс
  /// считается подъём до удара.
  int get tailMs => this == ritual ? EvRitualTiming.shock.inMilliseconds : 0;

  /// То, что меряется пределом класса.
  int get activeMs => durationMs - tailMs;

  /// «520 → 300 Гц», «2.2 кГц» — как в таблице README.
  String get sweep => from == to
      ? '${(from / 1000).toStringAsFixed(1)} кГц'
      : '${from.round()} → ${to.round()} Гц';

  /// «230 мс», у ритуала — «2600 + 900 мс».
  String get length => tailMs > 0 ? '$activeMs + $tailMs мс' : '$activeMs мс';
}

/// Удержание: две пилы с расстройкой 7 центов через низкие частоты,
/// срез уезжает вверх за время удержания, снизу — саб 55 Гц. Вершину
/// держит, пока кнопку не отпустят.
List<EvLayer> _charge(double from, double to) {
  final s = _s(EvMotion.hold);
  final cutoff = (from, to, 6.0);
  return [
    for (final detune in const [0.0, 7.0])
      EvToneLayer(
        dur: s,
        gain: .075,
        wave: EvWave.sawtooth,
        f0: 110,
        detune: detune,
        cutoff: cutoff,
        rise: .8,
        hold: true,
      ),
    EvToneLayer(dur: s, gain: .055, f0: 55, rise: 1, hold: true),
  ];
}

/// Щелчок, которым удержание кончается запуском.
const evStrike = [
  EvToneLayer(dur: .14, gain: .1, f0: 880, f1: 220),
  EvNoiseLayer(dur: .07, gain: .07, filter: EvFilter.highpass, f0: 2600),
];

/// Испарение: шум уезжает вверх и рассыпается шестью искрами. В прототипе
/// 420 мс и искры до 450 — длиннее класса событий; здесь всё в 400.
List<EvLayer> _evaporate(double from, double to) {
  const dur = .4, spark = .1;
  final r = EvArtRandom(4200);
  return [
    EvNoiseLayer(dur: dur, gain: .06, f0: from, f1: to, q: 3, linear: true),
    for (var i = 0; i < 6; i++)
      EvToneLayer(
        at: .05 + r.next() * (dur - .05 - spark),
        dur: spark,
        gain: .022,
        f0: 1400 + r.next() * 2600,
      ),
  ];
}

/// Ритуал: саб и шум поднимаются до удара, пять тиков делят подъём на
/// шесть стадий, удар — ровно на вспышке, хвост гаснет вместе с волной.
/// В прототипе удар звучал на 92 % от 2,6 с — за 208 мс до вспышки.
List<EvLayer> _ritual(double from, double to) {
  final strike = _s(EvRitualTiming.strike);
  final shock = _s(EvRitualTiming.shock);
  final rise = strike * .95;
  final r = EvArtRandom(2600);
  return [
    EvToneLayer(dur: rise, gain: .13, f0: from, f1: 62),
    EvNoiseLayer(dur: rise, gain: .085, f0: 180, f1: to, q: 1.1, linear: true),
    for (var i = 1; i < 6; i++)
      EvToneLayer(at: strike * i / 6, dur: .05, gain: .03, f0: 660, f1: 440),
    EvNoiseLayer(
      at: strike,
      dur: shock,
      gain: .2,
      filter: EvFilter.lowpass,
      f0: 9000,
      f1: 130,
      q: .8,
    ),
    EvToneLayer(at: strike, dur: .7, gain: .17, f0: 92, f1: 38),
    EvToneLayer(
      at: strike + .02,
      dur: .3,
      gain: .05,
      wave: EvWave.triangle,
      f0: 1320,
      f1: 330,
    ),
    for (var i = 0; i < 8; i++)
      EvToneLayer(
        at: strike + .12 + r.next() * (shock - .12 - .5),
        dur: .5,
        gain: .016,
        f0: 900 + r.next() * 3200,
      ),
  ];
}

/// Фоновая отдушина: тихий шум ниже 210 Гц, который дышит раз в 16,7 с.
/// Буфер — ровно один вдох; стык сведён за секунду, чтобы петля не
/// щёлкала.
Float32List evAmbient() {
  const period = 1 / .06, fade = 1.0;
  final n = (period * evSampleRate).round();
  final seam = (fade * evSampleRate).round();
  final raw = evRender([
    const EvNoiseLayer(
      dur: period + fade,
      gain: 1,
      filter: EvFilter.lowpass,
      f0: 210,
      q: .7,
      rise: 0,
      hold: true,
    ),
  ], seed: 210);
  final out = Float32List(n);
  for (var i = 0; i < n; i++) {
    final breath = .017 + .008 * math.sin(2 * math.pi * .06 * i / evSampleRate);
    final k = i < seam ? i / seam : 1.0;
    final v = raw[i] * k + (i < seam ? raw[n + i] * (1 - k) : 0);
    out[i] = v * breath;
  }
  return out;
}
