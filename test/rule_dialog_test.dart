import 'package:evaporate/bloc/rule_form/rule_form_bloc.dart';
import 'package:evaporate/l10n/app_localizations.dart';
import 'package:evaporate/l10n/app_localizations_en.dart';
import 'package:evaporate/l10n/app_localizations_ru.dart';
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
    String template = r'{APPSUPPORT}/Игра/Saves',
    SaveProfile profile = const SaveProfile(),
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
              builder: (_) => RuleDialog(
                template: template,
                label: 'Прежняя метка',
                gameDir: null,
                profile: profile,
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

  // Пустой шаблон разворачивается в рабочую папку процесса: снимок унёс
  // бы её, а восстановление с очисткой — очистило бы.
  testWidgets('пустой шаблон сохранить нельзя', (tester) async {
    final draft = await draftFrom(
      tester,
      locale: const Locale('ru'),
      label: 'Метка',
      template: '   ',
    );

    expect(draft, isNull);
  });

  // На другом устройстве две одинаковые метки неразличимы, и перенос
  // отказался бы от обоих правил.
  testWidgets('метку, занятую другим правилом, сохранить нельзя', (
    tester,
  ) async {
    const profile = SaveProfile(
      rules: [SavePathRule(id: 'a', label: 'Профиль', template: '{HOME}/a')],
    );

    final draft = await draftFrom(
      tester,
      locale: const Locale('ru'),
      label: ' профиль ',
      profile: profile,
    );

    expect(draft, isNull);
    expect(find.text(LRu().labelTaken), findsOneWidget);
  });

  testWidgets('пустая метка занята, если занята метка по умолчанию', (
    tester,
  ) async {
    const profile = SaveProfile(
      rules: [
        SavePathRule(
          id: 'a',
          label: SavePathRule.defaultLabel,
          template: '{HOME}/a',
        ),
      ],
    );

    final draft = await draftFrom(
      tester,
      locale: const Locale('ru'),
      label: '',
      profile: profile,
    );

    expect(draft, isNull);
  });

  testWidgets('свободную метку сохраняют', (tester) async {
    const profile = SaveProfile(
      rules: [SavePathRule(id: 'a', label: 'Профиль', template: '{HOME}/a')],
    );

    final draft = await draftFrom(
      tester,
      locale: const Locale('ru'),
      label: 'Настройки',
      profile: profile,
    );

    expect(draft!.label, 'Настройки');
  });
}
