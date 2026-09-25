import 'dart:math' as math;
import 'dart:typed_data';

import 'package:evaporate/ui/ev/design/effects.dart';
import 'package:evaporate/ui/ev/ev_app.dart';
import 'package:evaporate/ui/ev/launch/ritual_timeline.dart';
import 'package:evaporate/ui/ev/sound/ev_sound.dart';
import 'package:evaporate/ui/ev/sound/synth.dart';
import 'package:evaporate/ui/ev/sound/voices.dart';
import 'package:evaporate/ui/ev/widgets/ev_controls.dart';
import 'package:evaporate/ui/ev/widgets/ev_play_button.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Звук, который записывает, что ему велели.
class _Out implements EvAudioOut {
  final log = <String>[];

  @override
  Future<void> start() async => log.add('start');

  @override
  void volume(double gain) => log.add('volume $gain');

  @override
  void play(EvVoice voice) => log.add(voice.name);

  @override
  EvHoldVoice hold() {
    log.add('hold');
    return _Hold(log);
  }

  @override
  void ambient(bool on) => log.add('ambient $on');

  @override
  void dispose() {}
}

class _Hold implements EvHoldVoice {
  _Hold(this.log);

  final List<String> log;

  @override
  void release() => log.add('release');

  @override
  void strike() => log.add('strike');
}

/// Сколько раз сигнал пересекает ноль — грубая частота.
int _crossings(Float32List s, [int from = 0, int? to]) {
  var n = 0;
  for (var i = from + 1; i < (to ?? s.length); i++) {
    if ((s[i - 1] < 0) != (s[i] < 0)) n++;
  }
  return n;
}

double _peak(Float32List s) => s.fold(0.0, (m, x) => math.max(m, x.abs()));

double _rms(Float32List s, int from, int to) {
  var sum = 0.0;
  for (var i = from; i < to; i++) {
    sum += s[i] * s[i];
  }
  return math.sqrt(sum / (to - from));
}

/// Тумблер строки настроек по его подписи.
Finder _switch(String label) =>
    find.byWidgetPredicate((w) => w is EvSwitch && w.semanticLabel == label);

int _at(double seconds) => (seconds * evSampleRate).round();

void _window(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

/// Окно со звуком, который уже включён, и чистым журналом.
Future<_Out> _app(WidgetTester tester, {EvEffects? effects}) async {
  _window(tester);
  final out = _Out();
  final sound = EvSound(out: out);
  addTearDown(sound.dispose);
  final fx = effects ?? EvEffects.still();
  addTearDown(fx.dispose);
  await tester.pumpWidget(
    // Свой ключ: второе окно в том же тесте — новое, а не прежнее.
    EvaporateApp(
      key: UniqueKey(),
      effects: fx,
      sound: sound,
      readCatalog: false,
    ),
  );
  await _settle(tester);
  sound.enabled = true;
  await tester.pump();
  out.log.clear();
  return out;
}

void main() {
  group('голоса', () {
    test('каждый голос не длиннее своего класса', () {
      for (final v in EvVoice.values) {
        expect(
          v.activeMs,
          lessThanOrEqualTo(v.soundClass.limitMs),
          reason: v.label,
        );
      }
      // Ритуал поднимается ровно до удара, хвост гаснет вместе с волной.
      expect(EvVoice.ritual.activeMs, EvRitualTiming.strike.inMilliseconds);
      expect(EvVoice.ritual.tailMs, EvRitualTiming.shock.inMilliseconds);
      expect(EvVoice.swish.length, '120 мс');
      expect(EvVoice.ritual.length, '2600 + 900 мс');
    });

    test('ниже 120 Гц — только ритуал, интерфейс — в 200 Гц – 4 кГц', () {
      for (final v in EvVoice.values) {
        for (final l in v.layers.whereType<EvToneLayer>()) {
          final low = math.min(l.f0, l.f1);
          if (v.soundClass != EvSoundClass.ritual) {
            expect(low, greaterThanOrEqualTo(120), reason: v.label);
          }
        }
        if (v.soundClass == EvSoundClass.ui) {
          expect(math.min(v.from, v.to), greaterThanOrEqualTo(200));
          expect(math.max(v.from, v.to), lessThanOrEqualTo(4000));
        }
      }
    });

    test('удар ритуала — на вспышке, а не раньше', () {
      final loudest = EvVoice.ritual.layers.reduce(
        (a, b) => a.gain >= b.gain ? a : b,
      );
      expect(loudest.at, EvRitualTiming.strike.inMicroseconds / 1e6);
    });

    test('удержание держит вершину, пока не отпустят', () {
      final s = EvVoice.charge.render();
      final end = _at(EvVoice.charge.durationMs / 1000);
      final top = _rms(s, end - _at(.05), end);
      final middle = _rms(s, _at(.1), _at(.15));
      expect(top, greaterThan(middle * 2), reason: 'нарастает');
      expect(top, greaterThan(.03), reason: 'и не гаснет к концу');
    });
  });

  group('синтез', () {
    test('тон звучит на своей частоте и уходит, куда сказано', () {
      final flat = evRender(const [EvToneLayer(dur: .5, gain: .5, f0: 440)]);
      expect(_crossings(flat), closeTo(440, 10));

      final down = evRender(const [
        EvToneLayer(dur: .4, gain: .5, f0: 1200, f1: 300),
      ]);
      expect(
        _crossings(down, 0, _at(.2)),
        greaterThan(_crossings(down, _at(.2), _at(.4)) * 1.5),
      );
    });

    test('фильтр: верхние частоты режут низ, нижние — верх', () {
      final high = evRender(const [
        EvNoiseLayer(dur: .3, gain: .5, filter: EvFilter.highpass, f0: 4000),
      ]);
      final low = evRender(const [
        EvNoiseLayer(dur: .3, gain: .5, filter: EvFilter.lowpass, f0: 300),
      ]);
      expect(_crossings(high), greaterThan(_crossings(low) * 5));
      // На одном срезе верхние частоты дают больше пересечений, чем нижние.
      final under = evRender(const [
        EvNoiseLayer(dur: .3, gain: .5, filter: EvFilter.lowpass, f0: 4000),
      ]);
      expect(_crossings(high), greaterThan(_crossings(under) * 1.5));
    });

    test(
      'огибающая начинается и кончается тишиной, вершина — её громкость',
      () {
        final s = evRender(const [EvToneLayer(dur: .2, gain: .3, f0: 500)]);
        expect(s.first.abs(), lessThan(.001));
        expect(s.last.abs(), lessThan(.001));
        // И к концу слоя огибающая уже погасла, а не оборвалась.
        expect(s[_at(.2) - 1].abs(), lessThan(.005));
        expect(_peak(s), closeTo(.3, .02));
        expect(s.length, _at(.22), reason: '20 мс хвоста, как stop(t + .02)');
      },
    );

    test('WAV: 16 бит, моно, 44,1 кГц, данные — вдвое больше отсчётов', () {
      final wav = evWav(Float32List.fromList([0, .5, -1, 1]));
      final b = ByteData.sublistView(wav);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(b.getUint32(24, Endian.little), evSampleRate);
      expect(b.getUint16(34, Endian.little), 16);
      expect(b.getUint32(40, Endian.little), 8);
      expect(b.getInt16(46, Endian.little), 16384);
      expect(b.getInt16(48, Endian.little), -32767);
    });

    test('отдушина: один вдох, ниже 210 Гц, стык без щелчка', () {
      final a = evAmbient();
      expect(a.length, _at(1 / .06));
      // Ниже 210 Гц — меньше 420 пересечений нуля в секунду.
      expect(_crossings(a, 0, _at(1)), lessThan(420));
      final step = (a.first - a.last).abs();
      expect(step, lessThan(_peak(a) * .1));
    });
  });

  group('слой', () {
    test('выключен по умолчанию: ни звука', () {
      final out = _Out();
      final sound = EvSound(out: out)..play(EvVoice.tap);
      expect(sound.enabled, isFalse);
      expect(sound.hold(), isNull);
      expect(out.log, isEmpty);
    });

    test('включение заводит движок и отвечает «Готово»', () async {
      final out = _Out();
      final sound = EvSound(out: out)..enabled = true;
      await Future<void>.delayed(Duration.zero);
      expect(out.log, ['start', 'volume 0.5', 'ambient false', 'ok']);
      sound.volume = EvVolume.loud;
      expect(out.log.last, 'volume 0.85');
    });

    test('выключенный класс молчит, остальные звучат', () async {
      final out = _Out();
      final sound = EvSound(out: out)..enabled = true;
      await Future<void>.delayed(Duration.zero);
      out.log.clear();
      sound
        ..setHeard(EvSoundClass.ui, false)
        ..play(EvVoice.tap)
        ..play(EvVoice.err);
      expect(out.log, ['err']);
    });

    test('касания — не чаще раза в 60 мс', () async {
      var now = DateTime(2026);
      final out = _Out();
      final sound = EvSound(out: out, clock: () => now)..enabled = true;
      await Future<void>.delayed(Duration.zero);
      out.log.clear();
      sound.play(EvVoice.tick);
      now = now.add(const Duration(milliseconds: 30));
      sound.play(EvVoice.tick);
      now = now.add(const Duration(milliseconds: 40));
      sound.play(EvVoice.tick);
      expect(out.log, ['tick', 'tick']);
    });

    test('отдушина дышит, только включённая и в активном окне', () async {
      final out = _Out();
      final sound = EvSound(out: out)..ambient = true;
      expect(out.log, ['ambient false'], reason: 'слой выключен');
      sound.enabled = true;
      await Future<void>.delayed(Duration.zero);
      expect(out.log, contains('ambient true'));
      out.log.clear();
      sound.focused = false;
      expect(out.log, ['ambient false']);
    });
  });

  group('в окне', () {
    testWidgets('смена раздела звучит, «Пульт» входит так же', (tester) async {
      final out = await _app(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await _settle(tester);
      expect(out.log, ['swish']);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await _settle(tester);
      expect(out.log, ['swish', 'swish']);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(out.log.last, 'tick');
    });

    testWidgets('нажатие звучит у всего, что нажимается', (tester) async {
      final out = await _app(tester);
      await tester.tap(find.text('Подробнее'));
      await _settle(tester);
      expect(out.log, ['tap']);
    });

    testWidgets('удержание: отпустили — гаснет, дотянули — щелчок и ритуал', (
      tester,
    ) async {
      final out = await _app(tester);
      final play = find.byType(EvPlayButton).first;
      final early = await tester.startGesture(tester.getCenter(play));
      await tester.pump(const Duration(milliseconds: 300));
      await early.up();
      await tester.pump(const Duration(milliseconds: 300));
      expect(out.log, ['hold', 'release']);

      final full = await tester.startGesture(tester.getCenter(play));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await full.up();
      await tester.pump(const Duration(milliseconds: 500));
      expect(out.log, ['hold', 'release', 'hold', 'strike', 'ritual']);
    });

    testWidgets('без ритуала запуск отвечает «Готово»', (tester) async {
      final fx = EvEffects.still()..ritual = false;
      final out = await _app(tester, effects: fx);
      final play = find.byType(EvPlayButton).first;
      final g = await tester.startGesture(tester.getCenter(play));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await g.up();
      await tester.pump(const Duration(seconds: 2));
      expect(out.log, ['hold', 'strike', 'ok']);
    });

    testWidgets('дайджест испаряется со звуком, только если сорвались искры', (
      tester,
    ) async {
      Future<List<String>> dismiss(EvEffects fx) async {
        final out = await _app(tester, effects: fx);
        await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
        await _settle(tester);
        await tester.ensureVisible(find.text('Второй запуск'));
        await _settle(tester);
        await tester.tap(find.text('Второй запуск'));
        await _settle(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
        await _settle(tester);
        out.log.clear();
        await tester.tap(find.text('Всё понятно'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        return out.log;
      }

      expect(await dismiss(EvEffects.still()), isNot(contains('evaporate')));
      final sparks = EvEffects.still()..sparks = true;
      expect(await dismiss(sparks), contains('evaporate'));
      sparks.sparks = false;
      await tester.pump();
    });

    testWidgets('события движка звучат голосом своей причины', (tester) async {
      final out = await _app(tester);
      Future<void> pick(String name) async {
        await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
        await _settle(tester);
        // Строка в настройках — первая: та же подпись бывает в плашке.
        final row = find.text(name).first;
        await tester.ensureVisible(row);
        await _settle(tester);
        out.log.clear();
        await tester.tap(row);
        await _settle(tester);
      }

      await pick('Нет места на диске');
      expect(out.log, ['err']);
      await pick('Нет раздающих');
      expect(out.log, ['warn']);
      await pick('Нет раздающих');
      expect(out.log, isEmpty, reason: 'то же ещё раз — не событие');
      await pick('Конфликт версий');
      expect(out.log, ['warn']);
      await pick('Всё синхронизировано');
      expect(out.log, isEmpty, reason: 'всё хорошо — тишина');
      // «Нет сети» — состояние окна: пара меняется одним голосом.
      await pick('Сеть пропала');
      expect(out.log, ['warn']);
      await pick('Две активные');
      await pick('Нет сети');
      expect(out.log, ['warn']);
      await pick('Игра запущена');
      expect(out.log, isEmpty, reason: 'запуск уже прозвучал');
    });

    testWidgets('настройки: слой, класс, отдушина и каталог голосов', (
      tester,
    ) async {
      _window(tester);
      final out = _Out();
      final sound = EvSound(out: out);
      addTearDown(sound.dispose);
      final fx = EvEffects.still();
      addTearDown(fx.dispose);
      await tester.pumpWidget(
        EvaporateApp(effects: fx, sound: sound, readCatalog: false),
      );
      await _settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
      await _settle(tester);
      await tester.tap(find.text('Звук').first);
      await _settle(tester);

      await tester.tap(_switch('Звуковой слой'));
      await _settle(tester);
      expect(sound.enabled, isTrue);
      expect(out.log, containsAllInOrder(['start', 'ok']));

      await tester.tap(_switch('Интерфейс'));
      await _settle(tester);
      expect(sound.heard(EvSoundClass.ui), isFalse);
      await tester.tap(_switch('Фоновая отдушина'));
      await _settle(tester);
      expect(sound.ambient, isTrue);
      expect(out.log.last, 'ambient true');

      await tester.ensureVisible(find.bySemanticsLabel('Послушать: Ошибка'));
      await _settle(tester);
      await tester.tap(find.bySemanticsLabel('Послушать: Ошибка'));
      await tester.pump();
      expect(out.log.last, 'err');
      expect(find.text('2600 + 900 мс'), findsOneWidget);
      expect(find.text('520 → 300 Гц'), findsOneWidget);
    });
  });
}
