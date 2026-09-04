import 'dart:math' as math;

import 'package:evaporate/models/app_settings.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Относительная яркость по WCAG.
double _luminance(Color color) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// Отношение контраста двух цветов: от 1 (неразличимы) до 21.
double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final light = math.max(la, lb);
  final dark = math.min(la, lb);
  return (light + 0.05) / (dark + 0.05);
}

void main() {
  final palettes = {
    'тёмная': EvaporatePalette.dark,
    'светлая': EvaporatePalette.light,
  };

  group('читаемость', () {
    test('фон выделения использует точные цвета, текст контрастный', () {
      expect(EvaporatePalette.light.selection, const Color(0xFF201B31));
      expect(EvaporatePalette.dark.selection, const Color(0xFFE8E1CF));
      for (final palette in palettes.values) {
        expect(
          contrast(palette.onSelection, palette.selection),
          greaterThan(7),
        );
      }
      for (final theme in [EvaporateTheme.light(), EvaporateTheme.dark()]) {
        final palette = theme.extension<EvaporatePalette>()!;
        final style = theme.segmentedButtonTheme.style!;
        expect(
          style.backgroundColor!.resolve({WidgetState.selected}),
          palette.selection,
        );
        expect(
          style.foregroundColor!.resolve({WidgetState.selected}),
          palette.onSelection,
        );
      }
    });
    palettes.forEach((name, p) {
      // Классическая беда светлой темы: цвета, подобранные для тёмного фона,
      // на белом сливаются с ним. Поэтому меряем, а не смотрим.
      test('$name: основной текст читается на всех подложках', () {
        for (final background in [p.background, p.surface, p.surfaceHigh]) {
          expect(
            contrast(p.textPrimary, background),
            greaterThanOrEqualTo(7.0),
            reason: 'основной текст должен быть уверенно читаем',
          );
        }
      });

      test('$name: второстепенный текст дотягивает до нормы', () {
        for (final background in [p.background, p.surface, p.surfaceHigh]) {
          expect(
            contrast(p.textSecondary, background),
            greaterThanOrEqualTo(4.5),
            reason: 'им набраны подписи, а не украшения',
          );
        }
      });

      test('$name: акценты читаются как текст', () {
        for (final accent in [p.primary, p.accent, p.danger, p.warning]) {
          for (final background in [p.background, p.surface]) {
            expect(
              contrast(accent, background),
              greaterThanOrEqualTo(4.5),
              reason: 'ими пишут статусы и ошибки, а не только красят рамки',
            );
          }
        }
      });

      test('$name: надпись на кнопке читается', () {
        expect(contrast(p.onPrimary, p.primary), greaterThanOrEqualTo(4.5));
      });

      test('$name: границы видны, но не кричат', () {
        final ratio = contrast(p.outline, p.background);
        expect(ratio, greaterThan(1.2), reason: 'иначе рамок не видно вовсе');
        expect(
          ratio,
          lessThan(6.0),
          reason: 'разделитель не должен спорить с текстом',
        );
      });
    });
  });

  group('схемы различаются', () {
    test('светлая светлее тёмной', () {
      expect(
        _luminance(EvaporatePalette.light.background),
        greaterThan(_luminance(EvaporatePalette.dark.background)),
      );
    });

    test('яркость проставлена честно', () {
      expect(EvaporatePalette.dark.isDark, isTrue);
      expect(EvaporatePalette.light.isDark, isFalse);
    });

    // Осветлённая тёмная тема выглядит блёкло: акценты должны быть свои.
    test('акценты у схем разные, а не одни и те же', () {
      expect(
        EvaporatePalette.light.primary,
        isNot(EvaporatePalette.dark.primary),
      );
      expect(
        EvaporatePalette.light.textSecondary,
        isNot(EvaporatePalette.dark.textSecondary),
      );
    });

    test('переход между схемами не спотыкается', () {
      final middle = EvaporatePalette.dark.lerp(EvaporatePalette.light, 0.5);

      expect(middle.background, isNot(EvaporatePalette.dark.background));
      expect(middle.background, isNot(EvaporatePalette.light.background));
    });
  });

  group('тема отдаёт палитру', () {
    test('обе темы несут расширение с цветами', () {
      expect(
        EvaporateTheme.dark().extension<EvaporatePalette>(),
        EvaporatePalette.dark,
      );
      expect(
        EvaporateTheme.light().extension<EvaporatePalette>(),
        EvaporatePalette.light,
      );
    });

    test('подложка окна берётся из палитры', () {
      expect(
        EvaporateTheme.light().scaffoldBackgroundColor,
        EvaporatePalette.light.background,
      );
      expect(
        EvaporateTheme.dark().scaffoldBackgroundColor,
        EvaporatePalette.dark.background,
      );
    });

    testWidgets('цвета приходят из контекста', (tester) async {
      late EvaporatePalette seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: EvaporateTheme.light(),
          home: Builder(
            builder: (context) {
              seen = context.colors;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(seen, EvaporatePalette.light);
    });

    // Без расширения виджет не должен падать: тесты и превью часто
    // поднимают голый MaterialApp.
    testWidgets('без расширения берётся тёмная', (tester) async {
      late EvaporatePalette seen;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              seen = context.colors;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(seen, EvaporatePalette.dark);
    });
  });

  group('выбор темы хранится', () {
    test('режим переживает запись и чтение', () {
      for (final mode in ThemeMode.values) {
        final settings = AppSettings(installDir: '/games')
            .copyWith(themeMode: mode);

        final restored = AppSettings.fromJson(settings.toJson(), '/games');

        expect(restored.themeMode, mode);
      }
    });

    // Чужой или испорченный файл настроек не должен запирать пользователя
    // в теме, которую он не выбирал.
    test('незнакомое значение читается как «как в системе»', () {
      final restored = AppSettings.fromJson({
        'installDir': '/games',
        'themeMode': 'сепия',
      }, '/games');

      expect(restored.themeMode, ThemeMode.system);
    });

    test('по умолчанию тема системная', () {
      expect(
        const AppSettings(installDir: '/games').themeMode,
        ThemeMode.system,
      );
    });
  });
}
