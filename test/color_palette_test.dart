import 'dart:io';

import 'package:evaporate/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all Flutter colour definitions live in app_colors.dart', () {
    final definitions = RegExp(
      r'\bColors\s*\.|\b(?:Color|MaterialColor|MaterialAccentColor|HSLColor|HSVColor)\s*(?:\(|\.from\w*\s*\()',
    );
    final offenders = <String>[];
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      final path = file.path.replaceAll('\\', '/');
      if (!path.endsWith('.dart') || path == 'lib/ui/app_colors.dart') continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (definitions.hasMatch(lines[i])) offenders.add('$path:${i + 1}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Define colours in lib/ui/app_colors.dart and use theme.dart to access them.',
    );
  });

  test('theme exports particle colours without changing their values', () {
    expect(libraryInkColors, const [
      Color(0xFFF2C368),
      Color(0xFF49B7E0),
      Color(0xFFE0574A),
      Color(0xFFF2A93B),
      Color(0xFF9A7BD8),
      Color(0xFFF2C368),
    ]);
    expect(ambientParticleColor(false), const Color(0xFF8C3A10));
    expect(ambientParticleColor(true), const Color(0xFFE9C877));
    for (final dark in [false, true]) {
      expect(
        particleColor(isDark: dark, phase: 0, glow: 0),
        ambientParticleColor(dark),
      );
      expect(
        particleColor(isDark: dark, phase: 0, glow: 1),
        libraryInkColors.first,
      );
    }
  });

  test('wave and artwork palettes keep their theme values', () {
    expect(waveColors(true), const [
      Color(0xFFE9C877),
      Color(0xFF49B7E0),
      Color(0xFFE0574A),
      Color(0xFFC9C2B2),
    ]);
    expect(waveColors(false), const [
      Color(0xFFFF4A17),
      Color(0xFFFFC400),
      Color(0xFF0090A8),
      Color(0xFFB3261E),
    ]);
    for (final title in ['Celeste', 'Hades', 'Игра']) {
      final hue = (title.hashCode % 360).abs().toDouble();
      expect(gameCoverColors(title), [
        HSLColor.fromAHSL(1, hue, 0.34, 0.30).toColor(),
        HSLColor.fromAHSL(1, (hue + 24) % 360, 0.32, 0.13).toColor(),
      ]);

      // Свет корпуса держится выверенных якорей, а не всего круга:
      // свободный оттенок от хеша однажды выдаёт болотно-зелёный, и
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
    expect(AppColors.coverOverlay, Colors.black.withValues(alpha: 0.66));
    expect(AppColors.detailOverlay, Colors.black.withValues(alpha: 0.62));
    expect(AppColors.coverText, Colors.white);
    expect(AppColors.transparent, Colors.transparent);
  });
}
