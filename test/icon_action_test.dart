import 'package:evaporate/l10n/app_localizations.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:evaporate/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Мелкая клавиша со значком на карточке загрузки. Голый значок служебного
/// цвета на плотной подложке читался как украшение: найти паузу и отмену
/// глазами было нечем.
void main() {
  Future<ButtonStyle?> styleOf(
    WidgetTester tester, {
    required bool danger,
    required bool dark,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        locale: const Locale('ru'),
        theme: dark ? EvaporateTheme.dark() : EvaporateTheme.light(),
        home: Scaffold(
          body: IconAction(
            icon: Icons.pause,
            tooltip: 'пауза',
            onPressed: () {},
            danger: danger,
          ),
        ),
      ),
    );
    return tester.widget<IconButton>(find.byType(IconButton)).style;
  }

  for (final dark in [true, false]) {
    final scheme = dark ? 'Арклайт' : 'Картридж';

    testWidgets('$scheme: у клавиши есть подложка и кант, а не один значок', (
      tester,
    ) async {
      final style = await styleOf(tester, danger: false, dark: dark);
      final background = style?.backgroundColor?.resolve({});
      final side = style?.side?.resolve({});

      expect(background, isNotNull);
      expect(
        background!.a,
        greaterThan(0),
        reason: 'без подложки клавишу не найти глазами',
      );
      expect(side?.color.a, greaterThan(0));
    });

    // Отмена выбрасывает скачанное. Она обязана отличаться от паузы не
    // подписью в подсказке, а видом.
    testWidgets('$scheme: отмена окрашена иначе, чем пауза', (tester) async {
      final plain = await styleOf(tester, danger: false, dark: dark);
      final danger = await styleOf(tester, danger: true, dark: dark);

      expect(
        danger?.foregroundColor?.resolve({}),
        isNot(plain?.foregroundColor?.resolve({})),
      );
    });
  }

  // Заметность куплена цветом, а не размером: отмена теряет скачанное, и
  // растить ей область нажатия значило бы покупать видимость случайными
  // попаданиями.
  testWidgets('область нажатия осталась прежней', (tester) async {
    final style = await styleOf(tester, danger: true, dark: true);
    expect(style?.minimumSize?.resolve({}), const Size(30, 30));
  });
}
