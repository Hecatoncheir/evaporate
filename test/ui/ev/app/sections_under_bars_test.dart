import 'dart:io';

import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/models/app_section.dart';
import 'package:evaporate/ui/library/library_body.dart';
import 'package:evaporate/ui/library/library_grid.dart';
import 'package:evaporate/ui/library/library_heading.dart';
import 'package:evaporate/ui/saves/saves_page.dart';
import 'package:evaporate/ui/settings/settings_page.dart';
import 'package:evaporate/ui/shell/chrome_scroll_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_app.dart';

/// Чем срезано нарисованное [content] по пути к корню — прямоугольники в
/// координатах окна. Сравнивать их с полосами каркаса и есть проверка:
/// дойдёт ли прокрутка до стекла.
List<Rect> _clipsOver(RenderObject content) {
  final clips = <Rect>[];
  var child = content;
  for (var parent = child.parent; parent != null; parent = parent.parent) {
    if (parent.describeApproximatePaintClip(child) case final clip?) {
      clips.add(MatrixUtils.transformRect(child.getTransformTo(null), clip));
    }
    child = parent;
  }
  return clips;
}

/// Сливер, в котором лежит [box]: рисует его окно прокрутки или нет,
/// решает он.
RenderSliver _sliverOf(RenderObject box) {
  var node = box.parent;
  while (node is! RenderSliver) {
    node = node!.parent;
  }
  return node;
}

void main() {
  late Directory tmp;
  setUp(() async => tmp = await TestHarness.makeTempDir());
  tearDown(() => TestHarness.removeTempDir(tmp));

  Future<Size> open(
    WidgetTester tester,
    AppSection section, {
    int games = 1,
  }) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    await harness.pump(tester);
    for (var i = 0; i < games; i++) {
      harness.addGame(title: 'Hades $i');
    }
    harness.nav.add(SectionSelected(section));
    await tester.pumpAndSettle();
    // Отложенная запись добавленной игры.
    await tester.pump(const Duration(milliseconds: 500));
    return tester.view.physicalSize / tester.view.devicePixelRatio;
  }

  RenderObject contentOf(WidgetTester tester, Type page, Type content) =>
      tester.renderObject(
        find
            .descendant(of: find.byType(page), matching: find.byType(content))
            .first,
      );

  // Окно прокрутки кончается у кромки полос — подведённая стрелками строка
  // встаёт к его краю и под стеклом не прячется, — а рисуется прокрутка и
  // дальше, до края окна: стекло полос размывает уходящее содержимое.
  for (final (section, page, content) in [
    (AppSection.settings, SettingsPage, Column),
    (AppSection.saves, SavesPage, SliverPadding),
    (AppSection.library, LibraryGrid, SliverPadding),
  ]) {
    testWidgets('прокрутку раздела ${section.name} не срезает ничто ни '
        'сверху, ни снизу', (tester) async {
      final window = await open(tester, section);

      final clips = _clipsOver(contentOf(tester, page, content));

      expect(
        clips.where((clip) => clip.top > 0 || clip.bottom < window.height),
        isEmpty,
      );
    });
  }

  // Снятой обрезки мало: окно прокрутки рисует лишь то, что задевает его
  // самого, и ушедшее за край места раздела целиком под стеклом пропадало
  // рывком — полоса вспыхивала картинкой и гасла. Поэтому окно прокрутки
  // библиотеки само выходит под обе полосы.
  testWidgets('подпись библиотеки, ушедшая под верхнюю полосу, рисуется, '
      'пока её видно сквозь стекло', (tester) async {
    await open(tester, AppSection.library, games: 40);
    final top = tester.getRect(find.byType(LibraryBody)).top;
    final heading = find.byType(LibraryHeading, skipOffstage: false);
    final scroll = tester
        .widget<ChromeScrollView>(find.byType(ChromeScrollView))
        .controller;

    // Нижний край подписи — посередине верхней полосы: над местом
    // раздела, но под стеклом.
    scroll.jumpTo(tester.getRect(heading).bottom - top / 2);
    await tester.pump();

    expect(tester.getRect(heading).bottom, moreOrLessEquals(top / 2));
    expect(_sliverOf(tester.renderObject(heading)).geometry!.visible, isTrue);
  });
}
