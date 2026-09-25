import 'package:flutter/widgets.dart';

import 'voices.dart';

/// Громкость: три ступени, как в прототипе.
enum EvVolume {
  quiet('Тихо', .22),
  medium('Средне', .5),
  loud('Громко', .85);

  const EvVolume(this.label, this.gain);

  final String label;
  final double gain;
}

/// Удержание, которое звучит: его либо отпускают раньше срока, либо оно
/// кончается запуском.
abstract interface class EvHoldVoice {
  /// Отпустили раньше — гаснет за 120 мс.
  void release();

  /// Дотянули — гаснет за 60 мс, и звучит щелчок.
  void strike();
}

/// Куда звук уходит на самом деле. В окне — движок, в тестах — запись.
abstract interface class EvAudioOut {
  /// Завести движок и приготовить голоса. Повторный вызов ничего не делает.
  Future<void> start();

  void volume(double gain);

  void play(EvVoice voice);

  EvHoldVoice hold();

  void ambient(bool on);

  void dispose();
}

/// Звук в никуда: превью, тесты и окно, где движок не завёлся.
class EvSilentOut implements EvAudioOut {
  const EvSilentOut();

  @override
  Future<void> start() async {}

  @override
  void volume(double gain) {}

  @override
  void play(EvVoice voice) {}

  @override
  EvHoldVoice hold() => const _SilentHold();

  @override
  void ambient(bool on) {}

  @override
  void dispose() {}
}

class _SilentHold implements EvHoldVoice {
  const _SilentHold();

  @override
  void release() {}

  @override
  void strike() {}
}

/// Звуковой слой окна: включён ли, насколько громко, какие классы
/// звучат и дышит ли фон. Решает, звучать ли голосу; как звучать —
/// дело [EvAudioOut].
///
/// Правила из README:
/// * выключен по умолчанию — лаунчер не шумит на первом запуске;
/// * голос звучит, только если его класс включён;
/// * касания не чаще раза в 60 мс — иначе проводка мыши по полке трещит.
///
/// Правило «звук не громче картинки» решается там, где картинка: ритуал
/// звучит, только если он виден, испарение — только если искры сорвались.
class EvSound extends ChangeNotifier {
  /// [enabled] — включён с самого начала: движок заводится сразу, но без
  /// «Готово» — включения как жеста не было, и окно не должно звучать
  /// само по себе на старте.
  EvSound({
    required this._out,
    DateTime Function()? clock,
    bool enabled = false,
  }) : _clock = clock ?? DateTime.now {
    if (!enabled) return;
    _enabled = true;
    _out.start().then((_) {
      if (!_enabled) return;
      _out.volume(_volume.gain);
      _syncAmbient();
    });
  }

  final EvAudioOut _out;
  final DateTime Function() _clock;

  bool _enabled = false;
  EvVolume _volume = EvVolume.medium;
  final _classes = {for (final c in EvSoundClass.values) c: true};
  bool _ambient = false;
  bool _focused = true;
  DateTime? _lastTick;

  bool get enabled => _enabled;

  /// Включение — само по себе жест, поэтому отвечает «Готово».
  set enabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    notifyListeners();
    if (!value) {
      _out.ambient(false);
      return;
    }
    _out.start().then((_) {
      if (!_enabled) return;
      _out.volume(_volume.gain);
      _syncAmbient();
      play(EvVoice.ok);
    });
  }

  EvVolume get volume => _volume;
  set volume(EvVolume value) {
    if (value == _volume) return;
    _volume = value;
    _out.volume(value.gain);
    notifyListeners();
  }

  bool heard(EvSoundClass c) => _classes[c]!;

  void setHeard(EvSoundClass c, bool on) {
    if (_classes[c] == on) return;
    _classes[c] = on;
    notifyListeners();
  }

  /// Фоновая отдушина: по умолчанию выключена.
  bool get ambient => _ambient;
  set ambient(bool value) {
    if (value == _ambient) return;
    _ambient = value;
    _syncAmbient();
    notifyListeners();
  }

  /// Окно в фокусе. Отдушина дышит, только пока окно активно.
  set focused(bool value) {
    if (value == _focused) return;
    _focused = value;
    _syncAmbient();
  }

  void _syncAmbient() => _out.ambient(_enabled && _ambient && _focused);

  /// Прозвучит ли [voice] сейчас.
  bool allows(EvVoice voice) => _enabled && _classes[voice.soundClass]!;

  void play(EvVoice voice) {
    if (!allows(voice)) return;
    if (voice == EvVoice.tick) {
      final now = _clock();
      final last = _lastTick;
      if (last != null && now.difference(last) < _tickGap) return;
      _lastTick = now;
    }
    _out.play(voice);
  }

  static const _tickGap = Duration(milliseconds: 60);

  /// Удержание «Играть»; `null` — ему звучать нельзя.
  EvHoldVoice? hold() => allows(EvVoice.charge) ? _out.hold() : null;

  @override
  void dispose() {
    _out.dispose();
    super.dispose();
  }
}

/// Звук окна для виджетов под ним.
class EvSoundScope extends InheritedNotifier<EvSound> {
  const EvSoundScope({super.key, required EvSound sound, required super.child})
    : super(notifier: sound);

  /// Без звука — `null`: превью и тесты виджетов живут без него.
  static EvSound? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<EvSoundScope>()?.notifier;

  /// То же, но с подпиской: для настроек, которые рисуют его состояние.
  static EvSound? watch(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EvSoundScope>()?.notifier;
}
