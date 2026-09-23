import 'dart:io';

import 'package:evaporate/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('цвета заводятся только в папке темы', () {
    final definitions = RegExp(
      r'\bColors\s*\.|\b(?:Color|MaterialColor|MaterialAccentColor|HSLColor|HSVColor)\s*(?:\(|\.from\w*\s*\()',
    );
    final offenders = <String>[];
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      final path = file.path.replaceAll('\\', '/');
      if (!path.endsWith('.dart') || path.startsWith('lib/ui/theme/')) {
        continue;
      }
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (definitions.hasMatch(lines[i])) offenders.add('$path:${i + 1}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'цвет заводится в lib/ui/theme/, а виджеты берут его через тему',
    );
  });

  // Проверяем свойства, а не числа: список значений рядом с их же
  // копией из темы ловит только то, что кто-то поменял цвет, — и падает
  // на каждой правке оттенка, ничего о ней не сказав.
  test('частицы идут по кольцу цветов и возвращаются к нему', () {
    expect(libraryInkColors.first, libraryInkColors.last, reason: 'кольцо');
    expect(libraryInkColors, everyElement(isA<Color>()));

    for (final effects in [EffectsPalette.arclight, EffectsPalette.cartridge]) {
      // Без свечения частица своего цвета схемы, в полном — цвета кольца.
      expect(effects.particle(phase: 0, glow: 0), effects.particleBase);
      expect(effects.particle(phase: 0, glow: 1), libraryInkColors.first);

      // Соседние фазы дают разные цвета — иначе кольцо не водило бы.
      expect(
        effects.particle(phase: 0.1, glow: 1),
        isNot(effects.particle(phase: 0, glow: 1)),
      );
      // А полный оборот возвращает к началу: кольцо замкнуто.
      expect(
        effects.particle(phase: 0.5, glow: 1),
        effects.particle(phase: 0, glow: 1),
      );
    }
  });

  test('у схем свои цвета волны, и ни одна не повторяет другую', () {
    final arclight = EffectsPalette.arclight.waveColors;
    final cartridge = EffectsPalette.cartridge.waveColors;

    expect(arclight, hasLength(cartridge.length));
    expect(
      arclight.toSet(),
      hasLength(arclight.length),
      reason: 'без повторов',
    );
    expect(cartridge.toSet(), hasLength(cartridge.length));
    expect(arclight, isNot(cartridge), reason: 'два облика, а не один');
    for (final color in [...arclight, ...cartridge]) {
      expect(color.a, 1, reason: 'волна не прозрачная');
    }
  });

  test('обложка без картинки одинакова от запуска к запуску', () {
    for (final title in ['Celeste', 'Hades', 'Игра']) {
      final colors = gameCoverColors(title);

      expect(colors, hasLength(2));
      expect(
        gameCoverColors(title),
        colors,
        reason: 'та же игра — тот же цвет',
      );
      // Низ темнее верха: на этой паре лежит подпись, и градиент обязан
      // идти в одну сторону.
      expect(
        HSLColor.fromColor(colors.last).lightness,
        lessThan(HSLColor.fromColor(colors.first).lightness),
      );
    }
    expect(
      gameCoverColors('Celeste'),
      isNot(gameCoverColors('Hades')),
      reason: 'разные игры — разные обложки',
    );
  });

  test('свет корпуса держится выверенных якорей', () {
    for (final title in ['Celeste', 'Hades', 'Игра']) {
      // Свободный оттенок от хеша однажды выдаёт болотно-зелёный, и
      // оболочка выглядит сломанной, а не «своей у каждого».
      final ambient = gameAmbientColors(title);

      expect(ambient, hasLength(3));
      expect(gameAmbientColors(title), ambient, reason: 'один и тот же свет');
      final lead = HSLColor.fromColor(ambient.first).hue;
      expect(
        ambientHues.any((anchor) {
          final delta = (lead - anchor).abs();
          return (delta < 7) || (360 - delta < 7);
        }),
        isTrue,
        reason: 'оттенок $lead ушёл от якорей $ambientHues',
      );
    }
  });

  test('затемнения поверх обложки и правда затемняют', () {
    // Белый текст поверх картинки читается только по тёмной подложке, и
    // насколько она тёмная — вопрос не вкуса, а читаемости.
    expect(AppColors.coverOverlay.a, greaterThan(0.5));
    expect(HSLColor.fromColor(AppColors.coverText).lightness, 1);
    expect(AppColors.transparent.a, 0);
  });
}
