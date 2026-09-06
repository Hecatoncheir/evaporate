import 'dart:io';

import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/ui/settings/about_card.dart';
import 'package:evaporate/ui/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// Настройки проходятся сверху вниз одними стрелками — с клавиатуры и с
/// геймпада, который сводится к тем же действиям. Два места, где спуск
/// останавливался, стоили друг друга: поле ввода забирало стрелки себе, а
/// ленивый список просто не строил то, куда фокусу идти дальше.
void main() {
  late Directory tmp;

  // Временную папку готовим снаружи testWidgets: настоящий файловый
  // ввод-вывод внутри него не завершается никогда.
  setUp(() async => tmp = await TestHarness.makeTempDir());
  tearDown(() => TestHarness.removeTempDir(tmp));

  Future<void> frames(WidgetTester tester, [int count = 12]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 17));
    }
  }

  Future<void> openSettings(WidgetTester tester, TestHarness harness) async {
    await tester.pumpWidget(harness.buildApp());
    await frames(tester);
    harness.nav.add(const SectionSelected(3));
    await frames(tester);
  }

  // ListView строит только то, что видно, и следующей карточки в дереве
  // просто нет — фокусу некуда идти. С геймпада спуск упирался в последний
  // построенный переключатель и дальше не шёл.
  testWidgets('нижняя карточка построена, хотя до неё не долистали', (
    tester,
  ) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    await openSettings(tester, harness);

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(
      find.byType(AboutCard),
      findsOneWidget,
      reason: 'настройки строятся лениво — фокусу некуда идти вниз',
    );
  });

  // Стрелки в однострочном поле забирает редактор текста, и для него это
  // значит «ничего не делать»: спустившись в поле, фокус в нём и оставался.
  testWidgets('стрелка вниз уводит фокус из поля ввода', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    await openSettings(tester, harness);

    final field = find
        .descendant(
          of: find.byType(SettingsPage),
          matching: find.byType(TextField),
        )
        .first;
    final scrollable = find
        .descendant(
          of: find.byType(SettingsPage),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(field, 200, scrollable: scrollable);
    await tester.tap(field);
    await frames(tester);

    final editable = tester.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    expect(editable.focusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await frames(tester);

    expect(
      editable.focusNode.hasFocus,
      isFalse,
      reason: 'фокус остался в поле — стрелку забрал себе редактор текста',
    );
  });

  // Штатный обход ищет соседа по пересечению полос: «Показать» в карточке
  // журнала прижата вправо, а «Проверить обновления» под ней — влево, полосы
  // не пересекаются, и спуск перепрыгивал кнопку целиком. Достаться она
  // могла только после круга через боковую панель и всю страницу заново.
  testWidgets('спуск доходит до кнопки «Проверить обновления»', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    await openSettings(tester, harness);

    /// Подписи внутри узла, на котором сейчас фокус.
    List<String> labels() {
      final context = primaryFocus?.context;
      if (context is! Element) return const [];
      final found = <String>[];
      void walk(Element element) {
        final widget = element.widget;
        if (widget is Text && widget.data != null) found.add(widget.data!);
        if (found.length < 3) element.visitChildren(walk);
      }

      context.visitChildren(walk);
      return found;
    }

    bool inSettings() =>
        primaryFocus?.context?.findAncestorWidgetOfExactType<SettingsPage>() !=
        null;

    // Идём сверху донизу ровно один раз: круг через боковую панель вернул бы
    // фокус на страницу и скрыл бы пропуск.
    final seen = <String>[];
    for (var step = 0; step < 80; step++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await frames(tester, 3);
      if (step > 0 && !inSettings()) break;
      seen.addAll(labels());
    }

    expect(
      seen,
      contains('Проверить обновления'),
      reason: 'кнопку перепрыгнули: она левее того, что стоит над ней',
    );
  });

  // Спуск не должен упираться ни во что: ни в поле ввода, ни в конец
  // построенного. Двадцать шагов проходят все карточки насквозь.
  testWidgets('спуск стрелками идёт по настройкам, не застревая', (
    tester,
  ) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    await openSettings(tester, harness);

    final seen = <FocusNode>{};
    var stuck = 0;
    for (var i = 0; i < 20; i++) {
      final before = primaryFocus;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await frames(tester, 4);
      final after = primaryFocus;
      if (after != null) seen.add(after);
      if (after == before) stuck++;
    }

    expect(stuck, 0, reason: 'фокус остался на месте после нажатия вниз');
    expect(seen.length, greaterThan(8));
  });
}
