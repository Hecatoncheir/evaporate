import 'package:evaporate/l10n/app_localizations_en.dart';
import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/ui/library/primary_action.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:evaporate/ui/widgets/launcher_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/contrast.dart';
import '../../support/host_widget.dart';

/// Главная клавиша: два тона, заливка переходом и надпись поверх него.
void main() {
  // Ширина клавиши — ширина подписи, а где лежит надпись на переходе,
  // зависит от настоящего шрифта: служебный тестовый набрал бы её иначе.
  setUpAll(() async {
    for (final entry in {
      'Unbounded': 'assets/fonts/Unbounded.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });

  final schemes = {
    'ночь': (EvaporateTheme.dark(), LauncherButtonTheme.arclight),
    'день': (EvaporateTheme.light(), LauncherButtonTheme.cartridge),
  };

  Future<void> show(
    WidgetTester tester, {
    required ThemeData theme,
    required String label,
    required LauncherTone tone,
  }) => tester.pumpWidget(
    hostWidget(
      Center(
        child: LauncherActionButton(
          label: label,
          icon: Icons.play_arrow_rounded,
          tone: tone,
          onPressed: () {},
        ),
      ),
      theme: theme,
    ),
  );

  BoxDecoration face(WidgetTester tester) =>
      tester
              .widget<AnimatedContainer>(
                find.descendant(
                  of: find.byType(LauncherActionButton),
                  matching: find.byType(AnimatedContainer),
                ),
              )
              .decoration!
          as BoxDecoration;

  // Прежде переход шёл по диагонали, и хвост длинной подписи ложился на
  // остывающий низ: «Остановить» и «Продолжить» ночью давали 4,2–4,4.
  // Меряется цвет перехода там, где действительно лежит надпись, — у
  // каждого угла и края её строки.
  for (final MapEntry(key: name, value: (theme, look)) in schemes.entries) {
    testWidgets('$name: надпись читается на заливке по всей своей длине', (
      tester,
    ) async {
      final colors = theme.extension<EvaporatePalette>()!;
      final labels = [
        for (final l in [LRu(), LEn()])
          for (final action in PrimaryAction.values)
            (primaryActionLabel(l, action), primaryActionTone(action)),
      ];
      for (final (label, tone) in labels) {
        await show(tester, theme: theme, label: label, tone: tone);
        final key = tester.getRect(
          find.descendant(
            of: find.byType(LauncherActionButton),
            matching: find.byType(AnimatedContainer),
          ),
        );
        final text = tester.getRect(find.text(label));
        final fill = look.fillOf(tone);
        for (final point in [
          text.topLeft,
          text.topRight,
          text.centerLeft,
          text.centerRight,
          text.bottomLeft,
          text.bottomRight,
        ]) {
          expect(
            contrast(colors.onPrimary, _colorAt(fill, key, point)),
            greaterThanOrEqualTo(4.5),
            reason: '«$label» ($tone) у точки $point клавиши $key',
          );
        }
      }
    });

    testWidgets('$name: клавиша красится своим тоном', (tester) async {
      final colors = theme.extension<EvaporatePalette>()!;
      for (final tone in LauncherTone.values) {
        await show(tester, theme: theme, label: 'Играть', tone: tone);
        final decoration = face(tester);

        expect(decoration.gradient, look.fillOf(tone));
        expect(
          decoration.boxShadow!.first.color,
          look.depthOf(tone, colors),
          reason: 'клавиша стоит на торце своего тона',
        );
      }
      expect(
        look.fillOf(LauncherTone.launch),
        isNot(look.fillOf(LauncherTone.download)),
        reason: '«Скачать» и «Играть» различались бы только словом',
      );
    });
  }

  // Ореол — свет материала: ночью клавиша светит цветом своей заливки,
  // днём светлый корпус не светится, и она стоит на обычной тени.
  testWidgets('ореол есть ночью и светит своим тоном, днём его нет', (
    tester,
  ) async {
    final (night, nightLook) = schemes['ночь']!;
    final nightColors = night.extension<EvaporatePalette>()!;
    for (final tone in LauncherTone.values) {
      await show(tester, theme: night, label: 'Играть', tone: tone);
      expect(
        face(tester).boxShadow!.last.color,
        nightLook
            .haloOf(tone, nightColors)
            .withValues(alpha: nightLook.haloRest),
      );
    }

    final (day, _) = schemes['день']!;
    await show(tester, theme: day, label: 'Играть', tone: LauncherTone.launch);
    // Смену схемы `MaterialApp` ведёт плавно — ждём, пока она дойдёт.
    await tester.pumpAndSettle();
    expect(
      face(tester).boxShadow!.last.color,
      day.extension<EvaporatePalette>()!.shadow,
    );
  });
}

/// Цвет линейного перехода [fill], растянутого на [rect], в точке [point].
Color _colorAt(LinearGradient fill, Rect rect, Offset point) {
  final begin = fill.begin.resolve(TextDirection.ltr).withinRect(rect);
  final end = fill.end.resolve(TextDirection.ltr).withinRect(rect);
  final axis = end - begin;
  final along = point - begin;
  final t = ((along.dx * axis.dx + along.dy * axis.dy) / axis.distanceSquared)
      .clamp(0.0, 1.0);
  final stops = fill.stops!;
  for (var i = 1; i < stops.length; i++) {
    if (t <= stops[i]) {
      final local = (t - stops[i - 1]) / (stops[i] - stops[i - 1]);
      return Color.lerp(fill.colors[i - 1], fill.colors[i], local)!;
    }
  }
  return fill.colors.last;
}
