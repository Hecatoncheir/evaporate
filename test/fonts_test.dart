import 'package:evaporate/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Проверка самих шрифтов.
///
/// В тестовой среде Flutter по умолчанию подставляет служебный шрифт, поэтому
/// настоящие приходится загружать руками — иначе измерения ничего не значат.
Future<void> loadFont(String family, String path) async {
  final loader = FontLoader(family)..addFont(rootBundle.load(path));
  await loader.load();
}

double widthOf(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.width;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadFont('Nunito', 'assets/fonts/Nunito.ttf');
    await loadFont('Nunito Sans', 'assets/fonts/NunitoSans.ttf');
    await loadFont('JetBrains Mono', 'assets/fonts/JetBrainsMono.ttf');
  });

  // Главный вопрос к вариативным шрифтам: слушаются ли они обычного
  // fontWeight. Если нет, весь интерфейс отрисуется одним начертанием, а
  // заметить это по коду невозможно — только по ширине набранной строки.
  group('вариативные шрифты слушаются веса', () {
    for (final family in ['Nunito', 'Nunito Sans']) {
      test('$family меняет начертание вслед за весом', () {
        const text = 'Испарение сохранений 123';

        final light = widthOf(
          text,
          TextStyle(
            fontFamily: family,
            fontWeight: FontWeight.w300,
            fontSize: 40,
          ),
        );
        final bold = widthOf(
          text,
          TextStyle(
            fontFamily: family,
            fontWeight: FontWeight.w800,
            fontSize: 40,
          ),
        );

        expect(
          bold,
          greaterThan(light),
          reason: 'жирное начертание шире светлого — значит, ось веса работает',
        );
      });
    }

    // У моноширинного ширина от веса не зависит по определению, поэтому
    // сравниваем иначе: строка обязана быть ровно кратна ширине знака.
    test('JetBrains Mono остаётся моноширинным', () {
      const style = TextStyle(fontFamily: 'JetBrains Mono', fontSize: 30);

      final one = widthOf('m', style);
      final ten = widthOf('mmmmmmmmmm', style);

      expect(ten, closeTo(one * 10, 0.5));
      expect(widthOf('i', style), closeTo(one, 0.5));
    });
  });

  group('тема раздаёт шрифты', () {
    // Без этого шрифты остались бы объявленными, но неприменёнными: код
    // выглядел бы правильным, а интерфейс рисовался бы системным шрифтом.
    test('обычный текст набирается основным семейством', () {
      final theme = EvaporateTheme.dark();

      expect(theme.textTheme.bodyMedium?.fontFamily, EvaporateTheme.fontFamily);
      expect(theme.textTheme.labelLarge?.fontFamily, EvaporateTheme.fontFamily);
    });

    test('заголовки набираются вторым семейством', () {
      final theme = EvaporateTheme.dark();

      expect(
        theme.textTheme.titleLarge?.fontFamily,
        EvaporateTheme.displayFontFamily,
      );
      expect(
        theme.textTheme.headlineMedium?.fontFamily,
        EvaporateTheme.displayFontFamily,
      );
    });

    test('семейства не перепутаны местами', () {
      expect(EvaporateTheme.fontFamily, 'Nunito Sans');
      expect(EvaporateTheme.displayFontFamily, 'Nunito');
      expect(EvaporateTheme.monoFontFamily, 'JetBrains Mono');
    });
  });

  group('шрифты действительно подключены', () {
    test('кириллица набирается, а не отдаёт пустые квадраты', () {
      const style = TextStyle(fontFamily: 'Nunito', fontSize: 30);

      // У служебного шрифта все знаки одной ширины, у настоящего — нет.
      expect(widthOf('ш', style), isNot(closeTo(widthOf('і', style), 0.5)));
    });

    test('семейства отличаются друг от друга', () {
      const text = 'Evaporate';
      final sans = widthOf(
        text,
        const TextStyle(fontFamily: 'Nunito Sans', fontSize: 30),
      );
      final mono = widthOf(
        text,
        const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 30),
      );

      expect(sans, isNot(closeTo(mono, 1.0)));
    });
  });
}
