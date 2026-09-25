import 'dart:math' as math;
import 'dart:typed_data';

import '../art/key_art.dart';

/// Частота дискретизации синтеза и движка.
const evSampleRate = 44100;

/// С какой громкости огибающая начинает и чем кончается: `.0001`, как
/// `exponentialRampToValueAtTime` в Web Audio, — ноль экспонента не любит.
const _floor = .0001;

/// Хвост после последнего слоя: `stop(t + dur + .02)` в прототипе.
const _tail = .02;

/// Фильтр шумового слоя — `BiquadFilterNode.type`.
enum EvFilter { lowpass, highpass, bandpass }

/// Форма тона — `OscillatorNode.type`.
enum EvWave { sine, triangle, sawtooth }

/// Слой голоса: когда начинается, сколько длится и с какой вершиной
/// огибающей. Огибающая — экспонента от `.0001` к [gain] и обратно.
sealed class EvLayer {
  const EvLayer({
    required this.at,
    required this.dur,
    required this.gain,
    this.rise,
    this.hold = false,
  });

  /// Начало от старта голоса, с.
  final double at;

  /// Длительность, с.
  final double dur;

  final double gain;

  /// Доля длительности до вершины; `null` — как у слоя по умолчанию.
  final double? rise;

  /// После вершины не гаснет, а держится: так звучит удержание, пока
  /// кнопку не отпустили.
  final bool hold;

  double get end => at + dur;

  /// Когда огибающая доходит до вершины, с от начала слоя.
  double get attack => rise == null ? defaultAttack : dur * rise!;

  double get defaultAttack;
}

/// Шум через фильтр: `noise()` прототипа. [f0] → [f1] — частота среза,
/// экспонентой за всю длительность.
class EvNoiseLayer extends EvLayer {
  const EvNoiseLayer({
    super.at = 0,
    required super.dur,
    required super.gain,
    this.filter = EvFilter.bandpass,
    required this.f0,
    double? f1,
    this.q = 1,
    this.linear = false,
    super.rise,
    super.hold,
  }) : f1 = f1 ?? f0;

  final EvFilter filter;
  final double f0;
  final double f1;

  /// Добротность. У полосового — как есть, у низких и высоких частот —
  /// в децибелах, как в Web Audio.
  final double q;

  /// `curve: "lin"` — нарастает половину длительности, а не 6 %.
  final bool linear;

  @override
  double get defaultAttack => dur * (linear ? .5 : .06);
}

/// Тон: `tone()` прототипа. [f0] → [f1] — экспонентой, [detune] — в центах.
class EvToneLayer extends EvLayer {
  const EvToneLayer({
    super.at = 0,
    required super.dur,
    required super.gain,
    this.wave = EvWave.sine,
    required this.f0,
    double? f1,
    this.detune = 0,
    this.cutoff,
    super.rise,
    super.hold,
  }) : f1 = f1 ?? f0;

  final EvWave wave;
  final double f0;
  final double f1;
  final double detune;

  /// Низкие частоты: срез от и до, резонанс в децибелах; `null` — тон
  /// без фильтра.
  final (double, double, double)? cutoff;

  @override
  double get defaultAttack => math.min(.02, dur * .2);
}

/// Экспоненциальная развёртка от [a] к [b] за долю [t] ∈ 0…1.
double _sweep(double a, double b, double t) => a * math.pow(b / a, t);

/// Огибающая слоя в момент [t] от его начала.
double _envelope(EvLayer l, double t) {
  if (t < 0 || t > l.dur) return 0;
  final a = l.attack;
  if (t >= a && l.hold) return l.gain;
  return t < a
      ? _sweep(_floor, l.gain, t / a)
      : _sweep(l.gain, _floor, (t - a) / (l.dur - a));
}

/// Двухполюсный фильтр с частотой, которая меняется на каждом отсчёте, —
/// формулы Audio EQ Cookbook, те же, что у `BiquadFilterNode`.
class _Biquad {
  _Biquad(this.type, this.q);

  final EvFilter type;
  final double q;
  double _x1 = 0, _x2 = 0, _y1 = 0, _y2 = 0;

  // Коэффициенты считаются заново, только когда частота сдвинулась:
  // у отдушины она стоит, а длится та 17 секунд.
  double _freq = -1;
  var _k = (0.0, 0.0, 0.0, 0.0, 0.0);

  double process(double x, double freq) {
    if (freq != _freq) {
      _freq = freq;
      _k = _coefficients(freq);
    }
    final (b0, b1, b2, a1, a2) = _k;
    final y = b0 * x + b1 * _x1 + b2 * _x2 - a1 * _y1 - a2 * _y2;
    _x2 = _x1;
    _x1 = x;
    _y2 = _y1;
    _y1 = y;
    return y;
  }

  /// Коэффициенты, уже поделённые на a0.
  (double, double, double, double, double) _coefficients(double freq) {
    final f = freq.clamp(10.0, evSampleRate / 2 - 100);
    final w = 2 * math.pi * f / evSampleRate;
    final cw = math.cos(w), sw = math.sin(w);
    // Web Audio: у полосового Q — добротность, у остальных — резонанс
    // в децибелах.
    final alpha = type == EvFilter.bandpass
        ? sw / (2 * q)
        : sw / (2 * math.pow(10, q / 20));
    final (b0, b1, b2) = switch (type) {
      EvFilter.lowpass => ((1 - cw) / 2, 1 - cw, (1 - cw) / 2),
      EvFilter.highpass => ((1 + cw) / 2, -(1 + cw), (1 + cw) / 2),
      EvFilter.bandpass => (alpha, 0.0, -alpha),
    };
    final a0 = 1 + alpha;
    return (b0 / a0, b1 / a0, b2 / a0, -2 * cw / a0, (1 - alpha) / a0);
  }
}

double _wave(EvWave wave, double phase) => switch (wave) {
  EvWave.sine => math.sin(2 * math.pi * phase),
  EvWave.triangle => 1 - 4 * (phase - .5).abs(),
  EvWave.sawtooth => 2 * phase - 1,
};

/// Сводит слои в один буфер: моно, [evSampleRate], от старта голоса до
/// конца последнего слоя и ещё 20 мс. Шум — из генератора с [seed],
/// поэтому один и тот же голос всегда звучит одинаково.
Float32List evRender(List<EvLayer> layers, {int seed = 1}) {
  final end = layers.fold(0.0, (e, l) => math.max(e, l.end)) + _tail;
  final out = Float32List((end * evSampleRate).ceil());
  final rng = EvArtRandom(seed);
  for (final layer in layers) {
    _renderLayer(out, layer, rng);
  }
  return out;
}

/// Добавляет в [out] один слой с его огибающей.
void _renderLayer(Float32List out, EvLayer layer, EvArtRandom rng) {
  final from = (layer.at * evSampleRate).round();
  final count = math.min((layer.dur * evSampleRate).round(), out.length - from);
  final filter = switch (layer) {
    EvNoiseLayer(:final filter, :final q) => _Biquad(filter, q),
    EvToneLayer(:final cutoff?) => _Biquad(EvFilter.lowpass, cutoff.$3),
    EvToneLayer() => null,
  };
  var phase = 0.0;
  for (var i = 0; i < count; i++) {
    final t = i / evSampleRate;
    final k = t / layer.dur;
    final double sample;
    switch (layer) {
      case EvNoiseLayer(:final f0, :final f1):
        sample = filter!.process(rng.next() * 2 - 1, _sweep(f0, f1, k));
      case EvToneLayer():
        sample = _tone(layer, phase, k, filter);
        phase = (phase + _hz(layer, k) / evSampleRate) % 1;
    }
    out[from + i] += sample * _envelope(layer, t);
  }
}

/// Частота тона в долю [k] его длительности, с расстройкой.
double _hz(EvToneLayer l, double k) =>
    _sweep(l.f0, l.f1, k) * math.pow(2, l.detune / 1200);

/// Отсчёт тона: волна и, если есть, фильтр со своей развёрткой.
double _tone(EvToneLayer l, double phase, double k, _Biquad? filter) {
  final s = _wave(l.wave, phase);
  final cut = l.cutoff;
  return cut == null || filter == null
      ? s
      : filter.process(s, _sweep(cut.$1, cut.$2, k));
}

/// Буфер как WAV: 16 бит, моно. Движок принимает звук файлом.
Uint8List evWav(Float32List samples) {
  final data = samples.length * 2;
  final bytes = ByteData(44 + data);
  void text(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      bytes.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  text(0, 'RIFF');
  bytes.setUint32(4, 36 + data, Endian.little);
  text(8, 'WAVE');
  text(12, 'fmt ');
  bytes
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, evSampleRate, Endian.little)
    ..setUint32(28, evSampleRate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  text(36, 'data');
  bytes.setUint32(40, data, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    bytes.setInt16(44 + i * 2, v, Endian.little);
  }
  return bytes.buffer.asUint8List();
}
