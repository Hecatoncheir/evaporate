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
      Color(0xFFEF147C),
      Color(0xFFFF713F),
      Color(0xFFFFC52E),
      Color(0xFF05BDC9),
      Color(0xFF7552D9),
      Color(0xFFEF147C),
    ]);
    expect(ambientParticleColor(false), const Color(0xFF2F0346));
    expect(ambientParticleColor(true), const Color(0xFFF2685A));
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

  test('wave and artwork palettes keep their original values', () {
    expect(waveColors(true), const [
      Color(0xFF00E9F0),
      Color(0xFF4D7CFF),
      Color(0xFFA855F7),
      Color(0xFFFF2E93),
    ]);
    expect(waveColors(false), const [
      Color(0xFF00878B),
      Color(0xFF4664C0),
      Color(0xFF8041AC),
      Color(0xFFB6196A),
    ]);
    for (final title in ['Celeste', 'Hades', 'Игра']) {
      final hue = (title.hashCode % 360).abs().toDouble();
      expect(gameCoverColors(title), [
        HSLColor.fromAHSL(1, hue, 0.32, 0.27).toColor(),
        HSLColor.fromAHSL(1, (hue + 24) % 360, 0.30, 0.13).toColor(),
      ]);
    }
    expect(AppColors.coverOverlay, Colors.black.withValues(alpha: 0.66));
    expect(AppColors.detailOverlay, Colors.black.withValues(alpha: 0.62));
    expect(AppColors.windowCloseBackground, const Color(0xFFC42B1C));
    expect(AppColors.coverText, Colors.white);
    expect(AppColors.transparent, Colors.transparent);
  });
}
