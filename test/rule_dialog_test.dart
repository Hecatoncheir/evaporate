import 'package:evaporate/l10n/app_localizations.dart';
import 'package:evaporate/l10n/app_localizations_en.dart';
import 'package:evaporate/models/save_profile.dart';
import 'package:evaporate/ui/library/saves/rule_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Метка правила — не подпись, а ключ: по ней снимок с одного устройства
/// сходится с правилом на другом. Поэтому её переводят только при показе, а
/// хранят как есть.
void main() {
  /// Открывает диалог и возвращает то, что он отдал по нажатию «Сохранить».
  Future<RuleDraft?> draftFrom(
    WidgetTester tester, {
    required Locale locale,
    required String label,
  }) async {
    RuleDraft? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        locale: locale,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showDialog<RuleDraft>(
              context: context,
              builder: (_) => const RuleDialog(
                template: r'{APPSUPPORT}/Игра/Saves',
                label: 'Прежняя метка',
                gameDir: null,
              ),
            ),
            child: const Text('открыть'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('открыть'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, label);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    return result;
  }

  // Тот самый случай: интерфейс английский, метку не задали. Записанное
  // здесь «Saves» не сошлось бы с «Сохранениями» на русской машине, и сейв
  // просто не восстановился бы — без единого слова о том, почему.
  testWidgets('пустая метка на английском даёт константу, а не перевод', (
    tester,
  ) async {
    final draft = await draftFrom(
      tester,
      locale: const Locale('en'),
      label: '',
    );

    expect(draft, isNotNull);
    expect(draft!.label, SavePathRule.defaultLabel);
    expect(
      draft.label,
      isNot(LEn().saves),
      reason: 'в хранилище уходит ключ, а не подпись',
    );
  });

  testWidgets('на русском выходит та же самая константа', (tester) async {
    final draft = await draftFrom(
      tester,
      locale: const Locale('ru'),
      label: '',
    );

    expect(draft!.label, SavePathRule.defaultLabel);
  });

  testWidgets('заданную метку оставляют как есть, обрезая пробелы', (
    tester,
  ) async {
    final draft = await draftFrom(
      tester,
      locale: const Locale('en'),
      label: '  Профиль игрока  ',
    );

    expect(draft!.label, 'Профиль игрока');
  });
}
