import 'package:evaporate/ui/ev/design/effects.dart';
import 'package:evaporate/ui/ev/ev_app.dart';
import 'package:evaporate/ui/ev/gallery/gallery_page.dart';
import 'package:evaporate/ui/ev/gallery/gallery_since.dart';
import 'package:evaporate/ui/ev/modes/ev_pult.dart';
import 'package:evaporate/ui/ev/overlay/ev_overlay.dart';
import 'package:evaporate/ui/ev/sound/ev_sound.dart';
import 'package:evaporate/ui/ev/sound/voices.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Три размера окна из финальной сверки.
const _sizes = [Size(1280, 720), Size(1440, 900), Size(1900, 1100)];

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

class _Out implements EvAudioOut {
  final played = <EvVoice>[];

  @override
  Future<void> start() async {}

  @override
  void volume(double gain) {}

  @override
  void play(EvVoice voice) => played.add(voice);

  @override
  EvHoldVoice hold() => const EvSilentOut().hold();

  @override
  void ambient(bool on) {}

  @override
  void dispose() {}
}

Future<(EvSound, _Out)> _app(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final effects = EvEffects.still();
  addTearDown(effects.dispose);
  final out = _Out();
  final sound = EvSound(out: out);
  addTearDown(sound.dispose);
  await tester.pumpWidget(
    EvaporateApp(
      key: UniqueKey(),
      effects: effects,
      sound: sound,
      readCatalog: false,
    ),
  );
  await _settle(tester);
  return (sound, out);
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await _settle(tester);
}

void main() {
  for (final size in _sizes) {
    final name = '${size.width.round()} × ${size.height.round()}';

    testWidgets('$name: разделы, режимы и слои без ошибок раскладки', (
      tester,
    ) async {
      await _app(tester, size);
      final sections = [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
        LogicalKeyboardKey.digit5,
        LogicalKeyboardKey.digit6,
      ];
      for (final key in sections) {
        await _key(tester, key);
        expect(tester.takeException(), isNull, reason: '$name, $key');
      }

      await _key(tester, LogicalKeyboardKey.digit1);
      for (final view in ['Стена', 'Терминал', 'Витрина']) {
        await tester.tap(find.bySemanticsLabel(view));
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: '$name, $view');
      }

      await _key(tester, LogicalKeyboardKey.keyP);
      expect(find.byType(EvPult), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$name, Пульт');
      await _key(tester, LogicalKeyboardKey.escape);

      await _key(tester, LogicalKeyboardKey.digit4);
      await tester.ensureVisible(find.text('Оверлей в игре'));
      await _settle(tester);
      await tester.tap(find.text('Оверлей в игре'));
      await _settle(tester);
      expect(find.byType(EvOverlay), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$name, оверлей');
    });
  }

  testWidgets('галерея показывает всё, что появилось, и голоса звучат', (
    tester,
  ) async {
    final (sound, out) = await _app(tester, const Size(1440, 900));
    sound.enabled = true;
    await tester.pump();
    await _key(tester, LogicalKeyboardKey.digit4);
    // «Открыть» есть и у профиля друга — галерея последняя.
    final open = find.text('Открыть').last;
    await tester.ensureVisible(open);
    await _settle(tester);
    await tester.tap(open);
    await _settle(tester);
    expect(find.byType(GalleryPage), findsOneWidget);

    // Галерея строится по мере прокрутки: новое — ниже первой.
    final voice = find.text('${EvVoice.err.label} · ${EvVoice.err.length}');
    await tester.scrollUntilVisible(
      voice,
      400,
      scrollable: find
          .descendant(
            of: find.byType(GalleryPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await _settle(tester);
    expect(find.byType(GallerySince), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(voice);
    await tester.pump();
    expect(out.played.last, EvVoice.err);
  });
}
