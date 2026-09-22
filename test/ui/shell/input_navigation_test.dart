import 'dart:io';

import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/models/app_section.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/ui/library/toolbar/library_search_field.dart';
import 'package:evaporate/ui/widgets/nav_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamepads/gamepads.dart';

import '../../support/test_app.dart';

void main() {
  late Directory tmp;

  // Папка готовится снаружи теста: реальный файловый I/O внутри
  // testWidgets не завершается — там фейковое время.
  setUp(() async => tmp = await TestHarness.makeTempDir());

  tearDown(() => TestHarness.removeTempDir(tmp));

  /// Блоки обязаны создаваться внутри теста, иначе их события пойдут мимо
  /// фейкового времени и `pump` их не увидит.
  TestHarness attach() {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    return harness;
  }

  /// В поиске ли фокус.
  ///
  /// Узел поля принадлежит библиотеке, а не блоку: блок лишь просит увести
  /// фокус, и спрашивать о нём надо у того, кто полем владеет.
  bool searchHasFocus(WidgetTester tester) => tester
      .widget<LibrarySearchField>(find.byType(LibrarySearchField))
      .focusNode
      .hasFocus;

  Future<TestHarness> withGames(WidgetTester tester) async {
    final harness = attach();
    harness.addGame(title: 'Альфа', status: GameStatus.installed);
    harness.addGame(title: 'Бета', status: GameStatus.installed);
    await harness.pump(tester);
    return harness;
  }

  group('геймпад', () {
    testWidgets('бамперы переключают разделы по кругу', (tester) async {
      final harness = attach();
      await harness.pump(tester);
      expect(harness.nav.state.section, AppSection.library);

      await harness.tapButton(tester, GamepadButton.rightBumper);
      expect(harness.nav.state.section, AppSection.downloads);
      expect(find.text('СЕЙЧАС СКАЧИВАЕТСЯ'), findsOneWidget);
      expect(find.text('ДАЛЬШЕ В ОЧЕРЕДИ'), findsOneWidget);

      await harness.tapButton(tester, GamepadButton.leftBumper);
      expect(harness.nav.state.section, AppSection.library);

      // С первого раздела назад — на последний.
      await harness.tapButton(tester, GamepadButton.leftBumper);
      expect(harness.nav.state.section, AppSection.settings);
    });

    testWidgets('Y отправляет фокус в поиск', (tester) async {
      final harness = await withGames(tester);
      expect(searchHasFocus(tester), isFalse);

      await harness.tapButton(tester, GamepadButton.y);

      expect(searchHasFocus(tester), isTrue);
      expect(harness.nav.state.section, AppSection.library);
    });

    testWidgets('направления перемещают фокус', (tester) async {
      final harness = await withGames(tester);
      final before = primaryFocus;

      await harness.tapButton(tester, GamepadButton.dpadDown);

      expect(primaryFocus, isNot(same(before)));
      expect(primaryFocus?.hasFocus, isTrue);
    });

    testWidgets('левый стик работает как крестовина', (tester) async {
      final harness = await withGames(tester);
      final before = primaryFocus;

      await harness.moveStick(tester, GamepadAxis.leftStickY, -0.9);

      expect(primaryFocus, isNot(same(before)));
    });

    testWidgets('A активирует элемент под фокусом', (tester) async {
      final harness = await withGames(tester);

      // Название встречается и в списке, и в карточке справа — берём именно
      // плитку списка.
      final tileText = find.descendant(
        of: find.byType(NavTile),
        matching: find.text('Бета'),
      );
      expect(tileText, findsOneWidget);
      Focus.of(tester.element(tileText)).requestFocus();
      await tester.pumpAndSettle();

      await harness.tapButton(tester, GamepadButton.a);

      final selected = harness.library.state.gameById(
        harness.nav.state.selectedGameId!,
      );
      expect(selected?.title, 'Бета');
    });
  });

  group('клавиатура', () {
    testWidgets(
      'зона нечувствительности не перехватывает вертикальные стрелки',
      (tester) async {
        final harness = attach();
        await harness.pump(tester);
        harness.nav.add(const SectionSelected(AppSection.settings));
        await tester.pumpAndSettle();

        final slider = find.byType(Slider);
        expect(slider, findsOneWidget);
        Focus.of(tester.element(slider)).requestFocus();
        await tester.pump();
        final before = primaryFocus;
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();

        expect(primaryFocus, isNot(same(before)));
      },
    );

    for (final key in [
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.escape,
    ]) {
      testWidgets('${key.keyLabel} возвращает из поиска к выбранной игре', (
        tester,
      ) async {
        final harness = await withGames(tester);
        Focus.of(tester.element(find.text('Бета'))).requestFocus();
        await tester.pumpAndSettle();
        final selected = harness.nav.state.selectedGameId;
        harness.nav.add(const SearchFocusRequested());
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
        expect(searchHasFocus(tester), isFalse);
        expect(primaryFocus?.debugLabel, 'game:$selected');
        expect(harness.nav.state.openedGameId, isNull);
      });
    }

    testWidgets(
      'поиск сохраняет горизонтальное редактирование и возвращает к результату',
      (tester) async {
        final harness = await withGames(tester);
        await tester.enterText(find.byType(TextField), 'Бет');
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(searchHasFocus(tester), isTrue);
        final edit = tester.widget<EditableText>(find.byType(EditableText));
        expect(edit.controller.selection.baseOffset, 2);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(
          primaryFocus?.debugLabel,
          'game:${harness.nav.state.selectedGameId}',
        );
        expect(
          harness.library.state
              .gameById(harness.nav.state.selectedGameId)
              ?.title,
          'Бета',
        );
        expect(edit.controller.text, 'Бет');
      },
    );

    testWidgets('пустой результат отпускает поиск без ошибки', (tester) async {
      await withGames(tester);
      await tester.enterText(find.byType(TextField), 'не найдено');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(searchHasFocus(tester), isFalse);
      expect(tester.takeException(), isNull);
    });
    testWidgets('Ctrl+Tab переключает разделы', (tester) async {
      final harness = attach();
      await harness.pump(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(harness.nav.state.section, AppSection.downloads);
    });

    testWidgets('слэш переводит фокус в поиск', (tester) async {
      await withGames(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.pumpAndSettle();

      expect(searchHasFocus(tester), isTrue);
    });

    // «/» — ещё и символ: перехваченная всегда, она не набиралась ни в
    // пароле прокси, ни в самом поиске — «Fate/stay» было не найти.
    // Необработанное оболочкой нажатие система отдаёт полю как символ.
    testWidgets('в текстовом поле слэш остаётся символом', (tester) async {
      final harness = await withGames(tester);
      harness.nav.add(const SearchFocusRequested());
      await tester.pumpAndSettle();
      expect(searchHasFocus(tester), isTrue);

      final handled = await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.pumpAndSettle();

      expect(handled, isFalse, reason: 'оболочка съела символ');
      expect(searchHasFocus(tester), isTrue);
    });

    testWidgets('Ctrl+F уводит в поиск и из текстового поля', (tester) async {
      await withGames(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      final handled = await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);

      expect(handled, isTrue);
      expect(searchHasFocus(tester), isTrue);
    });

    testWidgets('стрелки перемещают фокус', (tester) async {
      await withGames(tester);
      final before = primaryFocus;

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(primaryFocus, isNot(same(before)));
    });

    testWidgets('Escape убирает фокус с поля поиска', (tester) async {
      final harness = await withGames(tester);
      harness.nav.add(const SearchFocusRequested());
      await tester.pumpAndSettle();
      expect(searchHasFocus(tester), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(searchHasFocus(tester), isFalse);
    });

    // Просьба о фокусе — счётчик, а не флаг: вторая такая же обязана
    // отличаться от первой, иначе состояние не изменится и фокус
    // останется там, куда его увёл человек.
    testWidgets('вторая просьба уводит фокус в поиск снова', (tester) async {
      final harness = await withGames(tester);
      harness.nav.add(const SearchFocusRequested());
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(searchHasFocus(tester), isFalse);

      harness.nav.add(const SearchFocusRequested());
      await tester.pumpAndSettle();

      expect(searchHasFocus(tester), isTrue);
    });
  });

  testWidgets('крестовина вниз и B возвращают из поиска к игре', (
    tester,
  ) async {
    final harness = await withGames(tester);
    for (final button in [
      GamepadButton.dpadDown,
      GamepadButton.b,
      GamepadButton.a,
    ]) {
      harness.nav.add(const SearchFocusRequested());
      await tester.pumpAndSettle();
      await harness.tapButton(tester, button);
      expect(searchHasFocus(tester), isFalse);
      expect(
        primaryFocus?.debugLabel,
        'game:${harness.nav.state.selectedGameId}',
      );
      expect(harness.nav.state.openedGameId, isNull);
    }
  });

  // Экран игры показывается вместо сетки, и при закрытии его виджеты
  // исчезают вместе с фокусом. Опереться фокусу было не на что, и он уезжал
  // в боковую панель — а человек ждёт, что вернётся на ту самую игру, с
  // экрана которой ушёл.
  testWidgets('закрытие экрана игры возвращает фокус на её плитку', (
    tester,
  ) async {
    final harness = await withGames(tester);
    Focus.of(tester.element(find.text('Бета'))).requestFocus();
    await tester.pumpAndSettle();
    final selected = harness.nav.state.selectedGameId;

    harness.nav.add(GameOpened(selected));
    await tester.pumpAndSettle();
    expect(harness.nav.state.openedGameId, selected);

    harness.nav.add(const GameOpened(null));
    await tester.pumpAndSettle();

    expect(
      primaryFocus?.debugLabel,
      'game:$selected',
      reason: 'фокус ушёл из библиотеки, хотя игра осталась выбранной',
    );
  });

  testWidgets('плитка показывает рамку фокуса', (tester) async {
    await withGames(tester);

    final tileText = find.descendant(
      of: find.byType(NavTile),
      matching: find.text('Альфа'),
    );
    Focus.of(tester.element(tileText)).requestFocus();
    await tester.pumpAndSettle();

    final container = tester.widget<AnimatedContainer>(
      find
          .descendant(
            of: find.ancestor(of: tileText, matching: find.byType(NavTile)),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    final border = (container.decoration as BoxDecoration?)?.border;
    expect(
      border?.top.color,
      isNot(Colors.transparent),
      reason: 'сфокусированная плитка должна быть видна',
    );
  });

  testWidgets('возврат из поиска прокручивает к выбранной игре вне экрана', (
    tester,
  ) async {
    final harness = attach();
    String? last;
    for (var i = 0; i < 80; i++) {
      last = harness.addGame(title: 'Game ${i.toString().padLeft(2, '0')}');
    }
    await harness.pump(tester);
    harness.nav.add(GameSelected(last));
    harness.nav.add(const SearchFocusRequested());
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(primaryFocus?.debugLabel, 'game:$last');
    expect(searchHasFocus(tester), isFalse);
    expect(find.text('Game 79'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
