import 'dart:io';

import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:evaporate/ui/widgets/glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

/// Возврат со страницы игры.
void main() {
  // Ищем по ключу перевода, а не по строке: правка формулировки в
  // ARB иначе роняет тест, ничего не сломав в приложении.
  final l = LRu();

  late Directory tmp;

  setUp(() async => tmp = await TestHarness.makeTempDir());
  tearDown(() => TestHarness.removeTempDir(tmp));

  /// Открывает страницу игры в окне заданной ширины.
  Future<void> openGame(WidgetTester tester, {double width = 1200}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    harness.addGame(title: 'Тестовая игра');
    await harness.pump(tester);

    await tester.tap(find.text('Тестовая игра').first);
    await tester.pumpAndSettle();
  }

  /// Подложка, на которой стоит «К библиотеке».
  Finder backSurface() => find.ancestor(
    of: find.text(l.backToLibrary),
    matching: find.byType(GlassSurface),
  );

  // Полоса во всю ширину читалась заголовком раздела и обещала больше, чем
  // несёт: за возврат отвечает одно слово в углу.
  testWidgets('подложка возврата обнимает клавишу, а не тянется по окну', (
    tester,
  ) async {
    await openGame(tester);

    final surface = tester.getRect(backSurface());
    final screen = tester.getRect(find.byType(MaterialApp));

    expect(
      surface.width,
      lessThan(screen.width / 3),
      reason: 'подложка должна быть по размеру клавиши, а не экрана',
    );
    // И стоит слева, а не посередине.
    expect(surface.left, lessThan(screen.width / 4));
  });

  testWidgets('в узком окне подложка тоже не растягивается', (tester) async {
    await openGame(tester, width: 620);

    final surface = tester.getRect(backSurface());
    final screen = tester.getRect(find.byType(MaterialApp));

    expect(surface.width, lessThan(screen.width * 0.75));
    expect(tester.takeException(), isNull);
  });

  // Фон под выбранным заметно мягче корпусных углов — это отдельный токен,
  // а не число по месту.
  testWidgets('у подложки и у самой клавиши один радиус', (tester) async {
    await openGame(tester);

    final surface = tester.widget<GlassSurface>(backSurface());
    expect(surface.radius, EvaporateTheme.radiusSelection);

    final button = tester.widget<TextButton>(
      find.ancestor(
        of: find.text(l.backToLibrary),
        matching: find.byType(TextButton),
      ),
    );
    final shape = button.style?.shape?.resolve({});
    expect(
      shape,
      isA<RoundedRectangleBorder>().having(
        (border) => (border.borderRadius as BorderRadius).topLeft.x,
        'скругление',
        EvaporateTheme.radiusSelection,
      ),
      reason: 'фон при наведении не должен рисовать свой угол внутри мягкого',
    );
  });
}
