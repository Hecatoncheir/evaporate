import 'package:evaporate/l10n/app_localizations.dart';
import 'package:evaporate/models/save_profile.dart';
import 'package:evaporate/ui/library/saves/rule_tile.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Строка правила сохранений в узкой колонке страницы игры.
void main() {
  // Метка и три тега стояли в одной строке без права переноса: длинная
  // метка, заданная человеком, вылезала за край карточки полосой ошибки.
  testWidgets('длинная метка с тегами переносится, а не вылезает за край', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: EvaporateTheme.dark(),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        locale: const Locale('ru'),
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: RuleTile(
              rule: const SavePathRule(
                id: 'r',
                label: 'Профиль второго игрока на общем компьютере',
                template: '/абсолютный/путь/к/сохранениям',
                platform: 'windows',
              ),
              gameDir: null,
              onRemove: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
