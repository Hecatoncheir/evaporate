import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'ev_sound.dart';
import 'synth.dart';
import 'voices.dart';

/// Голоса, отрендеренные в WAV: по голосу, щелчок удержания и отдушина.
typedef _Rendered = ({
  Map<EvVoice, Uint8List> voices,
  Uint8List strike,
  Uint8List ambient,
});

_Rendered _renderAll() => (
  voices: {for (final v in EvVoice.values) v: evWav(v.render())},
  strike: evWav(evRender(evStrike, seed: 880)),
  ambient: evWav(evAmbient()),
);

/// Звук через SoLoud: голоса синтезируются один раз при включении —
/// в отдельном изоляте, окно не ждёт, — и дальше играют из памяти.
/// Шина идёт через компрессор: порог −18 дБ, 4 : 1, атака 4 мс,
/// отпускание 180 мс — ритуал не перекричит интерфейс, даже если
/// совпадут.
///
/// Не завёлся движок — звука просто нет: окно без него работает.
class EvSoLoudOut implements EvAudioOut {
  /// [onError] — куда сказать, что движок не завёлся. Окно молчит и без
  /// этого, но приложению нужна строка в журнале: иначе «звука нет» у
  /// человека нечем объяснить.
  EvSoLoudOut({void Function(Object error)? onError})
    : _onError = onError ?? _print;

  final void Function(Object error) _onError;

  static void _print(Object error) => debugPrint('Звук не завёлся: $error');

  final _sources = <EvVoice, AudioSource>{};
  AudioSource? _strike;
  AudioSource? _ambientSource;
  SoundHandle? _ambient;
  Future<void>? _ready;
  bool _ambientWanted = false;

  SoLoud get _soloud => SoLoud.instance;

  bool get _live => _soloud.isInitialized && _sources.isNotEmpty;

  /// Сколько голосов в памяти движка: девять, когда он завёлся.
  @visibleForTesting
  int get loaded => _sources.length;

  @override
  Future<void> start() => _ready ??= _boot();

  Future<void> _boot() async {
    try {
      await _soloud.init(bufferSize: 1024);
      final compressor = _soloud.filters.compressorFilter..activate();
      compressor.threshold.value = -18;
      compressor.ratio.value = 4;
      compressor.attackTime.value = 4;
      compressor.releaseTime.value = 180;
      // compute, а не Isolate.run: в вебе изолятов нет, там он просто
      // посчитает на месте.
      final rendered = await compute((_) => _renderAll(), null);
      for (final MapEntry(key: v, value: wav) in rendered.voices.entries) {
        _sources[v] = await _soloud.loadMem('ev-${v.name}.wav', wav);
      }
      _strike = await _soloud.loadMem('ev-strike.wav', rendered.strike);
      _ambientSource = await _soloud.loadMem(
        'ev-ambient.wav',
        rendered.ambient,
      );
      ambient(_ambientWanted);
    } on Object catch (e) {
      _onError(e);
    }
  }

  @override
  void volume(double gain) {
    if (_soloud.isInitialized) _soloud.setGlobalVolume(gain);
  }

  @override
  void play(EvVoice voice) {
    final source = _sources[voice];
    if (_live && source != null) _soloud.play(source);
  }

  @override
  EvHoldVoice hold() {
    final source = _sources[EvVoice.charge];
    if (!_live || source == null) return const EvSilentOut().hold();
    return _SoLoudHold(_soloud, _soloud.play(source), _strike);
  }

  @override
  void ambient(bool on) {
    _ambientWanted = on;
    final source = _ambientSource;
    if (!_live || source == null) return;
    final playing = _ambient;
    if (on && playing == null) {
      final handle = _soloud.play(source, volume: 0, looping: true);
      _soloud.fadeVolume(handle, 1, const Duration(milliseconds: 800));
      _ambient = handle;
    } else if (!on && playing != null) {
      _soloud
        ..fadeVolume(playing, 0, const Duration(milliseconds: 900))
        ..scheduleStop(playing, const Duration(milliseconds: 1400));
      _ambient = null;
    }
  }

  @override
  void dispose() {
    if (_soloud.isInitialized) _soloud.deinit();
  }
}

class _SoLoudHold implements EvHoldVoice {
  _SoLoudHold(this._soloud, this._handle, this._strike);

  final SoLoud _soloud;
  final SoundHandle _handle;
  final AudioSource? _strike;

  void _fade(int ms) => _soloud
    ..fadeVolume(_handle, 0, Duration(milliseconds: ms))
    ..scheduleStop(_handle, Duration(milliseconds: ms + 20));

  @override
  void release() => _fade(120);

  @override
  void strike() {
    _fade(60);
    final s = _strike;
    if (s != null) _soloud.play(s);
  }
}
