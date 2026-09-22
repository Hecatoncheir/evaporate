import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/models/save_profile.dart';
import 'package:evaporate/ui/library/saves/rule_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/host_widget.dart';

/// Строка правила сохранений в узкой колонке страницы игры.
void main() {
  // Ищем по ключу перевода, а не по строке: правка формулировки в
  // ARB иначе роняет тест, ничего не сломав в приложении.
  final l = LRu();

  // Метка и три тега стояли в одной строке без права переноса: длинная
  // метка, заданная человеком, вылезала за край карточки полосой ошибки.
  testWidgets('длинная метка с тегами переносится, а не вылезает за край', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        SizedBox(
          width: 320,
          child: RuleTile(
            rule: const SavePathRule(
              id: 'r',
              label: 'Профиль второго игрока на общем компьютере',
              template: '/абсолютный/путь/к/сохранениям',
              platform: 'windows',
            ),
            exists: false,
            onRemove: () {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  /// Строка правила с заданным признаком «папка на диске».
  Future<void> pumpTile(WidgetTester tester, {required bool? exists}) =>
      tester.pumpWidget(
        hostWidget(
          SizedBox(
            width: 320,
            child: RuleTile(
              rule: const SavePathRule(
                id: 'r',
                label: 'Сохранения',
                template: '{APPSUPPORT}/Игра',
              ),
              exists: exists,
              onRemove: () {},
            ),
          ),
        ),
      );

  // Проверка идёт мимо отрисовки и приходит позже первого кадра. Пока её
  // нет, сказать «на диске нет» значит утверждать то, чего не знаешь, —
  // ровно там, где человек решает, чинить ли правило.
  testWidgets('непроверенное не объявляется отсутствующим', (tester) async {
    await pumpTile(tester, exists: null);

    expect(find.text(l.missingOnDisk), findsNothing);
    expect(find.byIcon(Icons.folder_off_outlined), findsNothing);
  });

  testWidgets('о пропавшей папке говорят прямо', (tester) async {
    await pumpTile(tester, exists: false);

    expect(find.text(l.missingOnDisk), findsOneWidget);
    expect(find.byIcon(Icons.folder_off_outlined), findsOneWidget);
  });
}
