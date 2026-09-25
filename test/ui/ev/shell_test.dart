import 'package:evaporate/l10n/app_localizations.dart';
import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/ui/ev/design/appearance.dart';
import 'package:evaporate/ui/ev/design/effects.dart';
import 'package:evaporate/ui/ev/design/theme.dart';
import 'package:evaporate/ui/ev/design/tokens.dart';
import 'package:evaporate/ui/ev/ev_app.dart';
import 'package:evaporate/ui/ev/shell/ev_hints_bar.dart';
import 'package:evaporate/ui/ev/shell/ev_palette.dart';
import 'package:evaporate/ui/ev/shell/ev_rail.dart';
import 'package:evaporate/ui/ev/shell/ev_section.dart';
import 'package:evaporate/ui/ev/shell/ev_shell.dart';
import 'package:evaporate/ui/ev/shell/ev_top_bar.dart';
import 'package:evaporate/ui/ev/util/plural.dart';
import 'package:evaporate/ui/ev/widgets/ev_controls.dart';
import 'package:evaporate/ui/ev/widgets/ev_surfaces.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void _window(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Досчитать экран до покоя. На библиотеке ядро «Играть» дышит бесконечно,
/// и pumpAndSettle не дождался бы конца: вместо него секунда — дольше
/// любого перехода — и кадр после неё.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

/// Приложение с неподвижной атмосферой: живой фон шёл бы бесконечно.
/// Сама атмосфера проверяется в atmosphere_test.dart.
Widget _app() {
  final effects = EvEffects.still();
  addTearDown(effects.dispose);
  return EvaporateApp(effects: effects);
}

Finder _crumb(String label) =>
    find.descendant(of: find.byType(EvTopBar), matching: find.text(label));

Finder _railItem(EvSection section) =>
    find.byWidgetPredicate((w) => w is EvRailItem && w.section == section);

EvSection _section(WidgetTester tester) =>
    tester.widget<EvShell>(find.byType(EvShell)).controller.section;

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await _settle(tester);
}

Future<void> _ctrlTab(WidgetTester tester, {bool shift = false}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await _settle(tester);
}

/// Каркас без приложения — для проверок, которым нужен свой экран.
Future<EvShellController> _bareShell(
  WidgetTester tester,
  Widget Function(BuildContext, EvSection) pageBuilder,
) async {
  final controller = EvShellController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildEvTheme(),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      locale: const Locale('ru'),
      home: EvShell(
        controller: controller,
        initials: 'ТТ',
        userName: 'Тест',
        pageBuilder: pageBuilder,
      ),
    ),
  );
  await _settle(tester);
  return controller;
}

void main() {
  test('поле экрана растёт ступенями, как в прототипе', () {
    expect(EvSpace.gutterFor(const Size(1280, 720)), 18, reason: 'низкое окно');
    expect(
      EvSpace.gutterFor(const Size(1000, 900)),
      22,
      reason: '2,2 % ширины',
    );
    expect(EvSpace.gutterFor(const Size(1440, 900)), 30, reason: 'потолок 30');
    expect(EvSpace.gutterFor(const Size(1920, 1080)), 42);
    expect(
      EvSpace.gutterFor(const Size(2560, 720)),
      44,
      reason: 'ширина сильнее высоты',
    );
  });

  test('число согласуется с существительным', () {
    String games(int n) => ruPlural(n, 'игра', 'игры', 'игр');
    expect([1, 2, 5, 11, 12, 14, 21, 22, 25, 101, 111].map(games), [
      'игра',
      'игры',
      'игр',
      'игр',
      'игр',
      'игр',
      'игра',
      'игры',
      'игр',
      'игра',
      'игр',
    ]);
  });

  testWidgets('минимальное окно 1280 × 720 собирается без переполнений', (
    tester,
  ) async {
    _window(tester, 1280, 720);
    await tester.pumpWidget(_app());
    await _settle(tester);

    expect(tester.getSize(find.byType(EvRail)).width, EvSpace.railWidth);
    expect(tester.getSize(find.byType(EvTopBar)).height, EvSpace.topBarHeight);
    expect(tester.getSize(find.byType(EvHintsBar)).height, EvSpace.hintsHeight);
    expect(tester.getBottomLeft(find.byType(EvHintsBar)).dy, 720);
    expect(_crumb('Библиотека'), findsOneWidget);

    // поиск и показатели прижаты к правому полю, а не висят посередине
    expect(
      tester.getTopRight(find.widgetWithText(EvPill, 'Движок готов')).dx,
      1280 - EvSpace.gutterFor(const Size(1280, 720)),
    );

    // все экраны по очереди — переполнение любого уронило бы тест
    for (final s in EvSection.values) {
      await _key(tester, _digitFor(s));
      expect(_crumb(s.labelOf(LRu())), findsOneWidget);
    }
  });

  testWidgets('настройки эффектов меняют общие EvEffects', (tester) async {
    _window(tester, 1440, 900);
    final effects = EvEffects.still();
    addTearDown(effects.dispose);
    await tester.pumpWidget(EvaporateApp(effects: effects));
    await _settle(tester);
    await _key(tester, LogicalKeyboardKey.digit4);

    final grain = _switch('Плёночное зерно');
    await tester.ensureVisible(grain);
    await _settle(tester);
    await tester.tap(grain);
    await _settle(tester);
    expect(effects.grain, isTrue);

    final parallax = _switch('Параллакс обложек');
    await tester.ensureVisible(parallax);
    await _settle(tester);
    await tester.tap(parallax);
    await _settle(tester);
    expect(effects.parallax, isTrue);

    final ritual = _switch('Ритуал запуска');
    await tester.ensureVisible(ritual);
    await tester.tap(ritual);
    await _settle(tester);
    expect(effects.ritual, isFalse);

    final hold = _switch('Удержание кнопки «Играть»');
    await tester.ensureVisible(hold);
    await tester.tap(hold);
    await _settle(tester);
    expect(effects.holdToPlay, isFalse);

    final eco = find.text('Эко');
    await tester.ensureVisible(eco);
    await _settle(tester);
    await tester.tap(eco);
    await _settle(tester);
    expect(effects.quality, EvEffectsQuality.eco);
  });

  testWidgets('рейл переключает раздел, повторный клик ничего не ломает', (
    tester,
  ) async {
    _window(tester, 1440, 900);
    await tester.pumpWidget(_app());
    await _settle(tester);

    await tester.tap(_railItem(EvSection.downloads));
    await _settle(tester);
    expect(_section(tester), EvSection.downloads);
    expect(_crumb('Загрузки'), findsOneWidget);

    await tester.tap(_railItem(EvSection.downloads));
    await _settle(tester);
    expect(_section(tester), EvSection.downloads);

    await tester.tap(find.byType(EvAvatar));
    await _settle(tester);
    expect(_section(tester), EvSection.profile);
  });

  testWidgets('цифры выбирают раздел, Ctrl+Tab идёт по кругу', (tester) async {
    _window(tester, 1440, 900);
    await tester.pumpWidget(_app());
    await _settle(tester);

    await _key(tester, LogicalKeyboardKey.digit3);
    expect(_section(tester), EvSection.saves);

    await _ctrlTab(tester);
    expect(_section(tester), EvSection.settings);

    await _key(tester, LogicalKeyboardKey.numpad6);
    expect(_section(tester), EvSection.profile);

    await _ctrlTab(tester);
    expect(_section(tester), EvSection.library, reason: 'с профиля по кругу');

    await _ctrlTab(tester, shift: true);
    expect(_section(tester), EvSection.profile, reason: 'и обратно');
  });

  testWidgets('смена облика не глушит клавиши каркаса', (tester) async {
    // смена темы пересобирает всё дерево, включая узел фокуса каркаса
    _window(tester, 1440, 900);
    await tester.pumpWidget(_app());
    await _settle(tester);

    EvAppearanceScope.of(tester.element(find.byType(EvShell))).skin =
        EvSkin.cryo;
    await _settle(tester);
    expect(
      Theme.of(tester.element(find.byType(EvShell)))
          .extension<EvTheme>()!
          .colors
          .hot1,
      EvColors.cryo.hot1,
    );

    await _key(tester, LogicalKeyboardKey.digit2);
    expect(_section(tester), EvSection.downloads);
  });

  testWidgets('в поле ввода цифры печатаются, а фокус не теряется', (
    tester,
  ) async {
    _window(tester, 1440, 900);
    final controller = await _bareShell(
      tester,
      (context, section) => ListView(
        primary: true,
        children: [
          if (section == EvSection.library)
            const TextField(key: Key('field'))
          else
            Text(section.labelOf(LRu())),
        ],
      ),
    );

    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();
    await _key(tester, LogicalKeyboardKey.digit2);
    expect(controller.section, EvSection.library, reason: 'цифра — в поле');

    // Enter снимает фокус с поля и отдаёт ближайшей области фокуса —
    // это должна быть область каркаса, а не маршрут над ним
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await _key(tester, LogicalKeyboardKey.digit3);
    expect(controller.section, EvSection.saves);

    // снова в поле; Ctrl+Tab ничего не печатает и работает из него
    await _key(tester, LogicalKeyboardKey.digit1);
    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();
    await _ctrlTab(tester);
    expect(controller.section, EvSection.downloads);

    // поле исчезло вместе с экраном — фокус вернулся в каркас
    await _key(tester, LogicalKeyboardKey.digit4);
    expect(controller.section, EvSection.settings);
  });

  testWidgets('повторный выбор раздела возвращает экран к началу', (
    tester,
  ) async {
    _window(tester, 1440, 900);
    await _bareShell(
      tester,
      (context, section) => ListView(
        key: const Key('page'),
        primary: true,
        children: [
          for (var i = 0; i < 60; i++) SizedBox(height: 80, child: Text('$i')),
        ],
      ),
    );

    ScrollPosition position() => tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(const Key('page')),
            matching: find.byType(Scrollable),
          ),
        )
        .position;

    await tester.drag(find.byKey(const Key('page')), const Offset(0, -1500));
    await _settle(tester);
    expect(position().pixels, greaterThan(0));

    await tester.tap(_railItem(EvSection.library));
    await _settle(tester);
    expect(position().pixels, 0);
  });

  testWidgets('подсказка рейла появляется при наведении', (tester) async {
    _window(tester, 1440, 900);
    await tester.pumpWidget(_app());
    await _settle(tester);

    double opacity() => tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: find.text('Загрузки · 2'),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;

    expect(opacity(), 0);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(_railItem(EvSection.downloads)));
    await _settle(tester);
    expect(opacity(), 1);

    await mouse.moveTo(const Offset(700, 400));
    await _settle(tester);
    expect(opacity(), 0);
  });

  testWidgets('Tab доводит фокус до рейла, Enter открывает раздел', (
    tester,
  ) async {
    _window(tester, 1440, 900);
    await tester.pumpWidget(_app());
    await _settle(tester);

    EvSection? focusedRail() => FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<EvRailItem>()
        ?.section;

    for (var i = 0; i < 12 && focusedRail() != EvSection.saves; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(focusedRail(), EvSection.saves);

    await _key(tester, LogicalKeyboardKey.enter);
    expect(_section(tester), EvSection.saves);
  });

  testWidgets('узкое окно: навигация внизу, подсказок нет', (tester) async {
    _window(tester, 600, 900);
    await tester.pumpWidget(_app());
    await _settle(tester);

    expect(find.byType(EvRail), findsNothing);
    expect(find.byType(EvHintsBar), findsNothing);
    expect(find.byType(EvBottomNav), findsOneWidget);
    expect(tester.getBottomLeft(find.byType(EvBottomNav)).dy, 900);

    await tester.tap(
      find.descendant(
        of: find.byType(EvBottomNav),
        matching: find.bySemanticsLabel('Друзья'),
      ),
    );
    await _settle(tester);
    expect(_crumb('Друзья'), findsOneWidget);
  });

  testWidgets('палитра: слэш открывает, поиск фильтрует, Enter выполняет', (
    tester,
  ) async {
    _window(tester, 1440, 900);
    await tester.pumpWidget(_app());
    await _settle(tester);

    await _key(tester, LogicalKeyboardKey.slash);
    expect(find.byType(EvPalette), findsOneWidget);

    // цифры принадлежат полю палитры, раздел не меняется
    await _key(tester, LogicalKeyboardKey.digit2);
    expect(_section(tester), EvSection.library);

    await tester.enterText(find.byType(TextField), 'загрузки');
    await _settle(tester);
    expect(
      find.descendant(
        of: find.byType(EvPalette),
        matching: find.text('Загрузки'),
      ),
      findsOneWidget,
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);
    expect(find.byType(EvPalette), findsNothing);
    expect(_section(tester), EvSection.downloads);

    // Ctrl+K, поиск по жанру, стрелки и Esc
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'хоррор');
    await _settle(tester);
    expect(
      find.descendant(
        of: find.byType(EvPalette),
        matching: find.text('Глубина 9'),
      ),
      findsOneWidget,
    );
    await _key(tester, LogicalKeyboardKey.escape);
    expect(find.byType(EvPalette), findsNothing);

    // команда меняет облик всего приложения
    await _key(tester, LogicalKeyboardKey.slash);
    await tester.enterText(find.byType(TextField), 'nebula');
    await _settle(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);
    expect(
      EvAppearanceScope.of(tester.element(find.byType(EvShell))).skin,
      EvSkin.nebula,
    );
  });
}

LogicalKeyboardKey _digitFor(EvSection s) => [
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
][s.index];

/// Тумблер настройки по подписи его строки.
Finder _switch(String label) =>
    find.byWidgetPredicate((w) => w is EvSwitch && w.semanticLabel == label);
