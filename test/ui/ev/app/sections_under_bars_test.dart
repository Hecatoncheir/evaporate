import 'dart:io';

import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/models/app_section.dart';
import 'package:evaporate/ui/library/library_grid.dart';
import 'package:evaporate/ui/saves/saves_page.dart';
import 'package:evaporate/ui/settings/settings_page.dart';
import 'package:flutter/material.dart';
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

void main() {
  late Directory tmp;
  setUp(() async => tmp = await TestHarness.makeTempDir());
  tearDown(() => TestHarness.removeTempDir(tmp));

  Future<Size> open(WidgetTester tester, AppSection section) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    await harness.pump(tester);
    harness.addGame(title: 'Hades');
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
  ]) {
    testWidgets('прокрутка раздела ${section.name} рисуется и под полосами '
        'каркаса', (tester) async {
      final window = await open(tester, section);

      final clips = _clipsOver(contentOf(tester, page, content));

      expect(
        clips.where((clip) => clip.top > 0 || clip.bottom < window.height),
        isEmpty,
      );
    });
  }

  testWidgets('сетка библиотеки уходит низом под строку подсказок', (
    tester,
  ) async {
    final window = await open(tester, AppSection.library);

    final clips = _clipsOver(contentOf(tester, LibraryGrid, SliverPadding));

    expect(clips.where((clip) => clip.bottom < window.height), isEmpty);
    // Сверху её срезает полка: выше лежат крупный кадр и вкладки.
    expect(clips.any((clip) => clip.top > 0), isTrue);
  });
}
