import 'dart:io';
import 'dart:ui' as ui;

import 'package:evaporate/l10n/app_localizations.dart';
import 'package:evaporate/ui/shell/shell_layout.dart';
import 'package:evaporate/ui/shell/top_bar.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:evaporate/ui/window/app_window_frame.dart';
import 'package:evaporate/ui/window/window_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import '../../support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('window_manager');
  final calls = <MethodCall>[];
  var maximized = false;
  var fullScreen = false;
  String? failedMethod;
  late Directory tmp;

  setUpAll(() async {
    if (Platform.environment['WINDOW_FRAME_PREVIEW'] == null) return;
    for (final entry in {
      'Unbounded': 'assets/fonts/Unbounded.ttf',
      'Golos Text': 'assets/fonts/GolosText.ttf',
      'JetBrains Mono': 'assets/fonts/JetBrainsMono.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });

  setUp(() async {
    tmp = await TestHarness.makeTempDir();
    calls.clear();
    maximized = false;
    fullScreen = false;
    failedMethod = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == failedMethod) {
            throw PlatformException(
              code: 'denied',
              message: 'Window operation denied',
            );
          }
          switch (call.method) {
            case 'isMaximized':
              return maximized;
            case 'isFullScreen':
              return fullScreen;
            case 'isFocused':
              return true;
            case 'maximize':
              maximized = true;
            case 'unmaximize':
              maximized = false;
            case 'setFullScreen':
              fullScreen = (call.arguments as Map)['isFullScreen'] as bool;
          }
          return null;
        });
  });

  tearDown(() => TestHarness.removeTempDir(tmp));

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  Future<void> pump(
    WidgetTester tester, {
    Locale locale = const Locale('ru'),
  }) async {
    tester.view.physicalSize = const Size(900, 620);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: EvaporateTheme.dark(),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        locale: locale,
        builder: (context, child) => AppWindowFrame(child: child!),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(content: Text('Dialog')),
              ),
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Полосы, за которые тянут края окна, лежат поверх всего — иначе до них
  // не дотянуться. Значит они легко накрывают то, что под ними, и проверять
  // тут нужно именно геометрию.
  /// Приложение целиком под своей рамкой: клавиши окна живут в верхней
  /// рейке, и без оболочки их не достать.
  Future<void> pumpApp(WidgetTester tester, {Locale? locale}) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    tester.view.physicalSize = const Size(1100, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness.buildApp(
        locale: locale,
        builder: (context, child) => AppWindowFrame(child: child!),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Полосы, за которые тянут края окна, лежат поверх всего — иначе до них
  // не дотянуться. Значит они легко накрывают то, что под ними, и проверять
  // тут нужно именно геометрию.
  group('полосы изменения размера', () {
    // Орган управления под невидимой полосой — не просто мёртвая точка.
    // Нажатие уходит в системный цикл изменения размера, отпускания мыши
    // Flutter не видит, и отложенное нажатие достаётся тому, что под
    // полосой. Клавиши окна стоят в верхней рейке, а она отступает от края
    // окна дальше, чем полоса толста, — но числа эти живут в разных файлах
    // и сходятся только здесь.
    test('полоса у края не достаёт до верхней рейки', () {
      expect(WindowChrome.edge, lessThan(ShellLayout.compactInset));
      expect(
        ShellLayout.compactInset,
        lessThanOrEqualTo(ShellLayout.wideInset),
      );
    });

    test('все не толще заявленной толщины', () {
      for (final zone in WindowChrome.resizeZones(const Size(900, 600))) {
        expect(
          zone.rect.shortestSide,
          lessThanOrEqualTo(WindowChrome.edge),
          reason: 'полоса ${zone.edge.name} толще заявленного',
        );
      }
    });

    // Углом тянут за угол, и полоса в четыре точки — это четыре точки:
    // промахнуться по ней легко, поэтому вдоль каждой стороны угол длиннее.
    test('углы длиннее, чем толще', () {
      final zones = WindowChrome.resizeZones(const Size(900, 600));
      final corners = zones.where(
        (zone) => zone.edge.name.length > 'bottom'.length,
      );

      expect(corners, hasLength(8));
      for (final zone in corners) {
        expect(zone.rect.longestSide, WindowChrome.corner);
      }
    });

    test('каждый край окна можно потянуть', () {
      final edges = WindowChrome.resizeZones(const Size(900, 600))
          .map((zone) => zone.edge)
          .toSet();

      expect(edges, hasLength(8));
    });
  });

  testWidgets('клавиши рейки сворачивают, разворачивают и закрывают окно', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Свернуть окно'));
    await tester.pumpAndSettle();
    expect(calls.any((c) => c.method == 'minimize'), isTrue);

    await tester.tap(find.byTooltip('Развернуть окно'));
    await tester.pumpAndSettle();
    expect(maximized, isTrue);
    expect(find.byKey(const ValueKey('window-resize-top')), findsNothing);

    await tester.tap(find.byTooltip('Восстановить размер окна'));
    await tester.pumpAndSettle();
    expect(maximized, isFalse);
    expect(
      find.byKey(const ValueKey('window-resize-top')),
      Platform.isMacOS ? findsNothing : findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('rail-quit')));
    await tester.pumpAndSettle();
    expect(calls.any((c) => c.method == 'close'), isTrue);
    expect(tester.takeException(), isNull);
  });

  // Без своей рамки клавиш окна в рейке нет вовсе: окном тогда
  // распоряжается система, и вторых клавиш ему не нужно.
  testWidgets('без рамки рейка клавиш окна не показывает', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    tester.view.physicalSize = const Size(1100, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('rail-minimize')), findsNothing);
    expect(find.byKey(const ValueKey('rail-maximize')), findsNothing);
    expect(find.byKey(const ValueKey('window-drag-region')), findsNothing);
    expect(find.byKey(const ValueKey('rail-quit')), findsOneWidget);
  });

  testWidgets(
    'у развёрнутого при старте окна нет ни краёв для растягивания, ни скругления',
    (tester) async {
      fullScreen = true;
      await pumpApp(tester);
      final clip = tester.widget<ClipRRect>(
        find.byKey(const ValueKey('window-clip')),
      );
      expect(clip.borderRadius, BorderRadius.zero);
      expect(find.byKey(const ValueKey('window-resize-top')), findsNothing);
      await tester.tap(find.byTooltip('Восстановить размер окна'));
      await tester.pumpAndSettle();
      expect(fullScreen, isFalse);
      expect(calls.any((c) => c.method == 'setFullScreen'), isTrue);
    },
  );

  testWidgets('рейка тянет окно, а двойное нажатие разворачивает', (
    tester,
  ) async {
    await pumpApp(tester);
    final rail = find.descendant(
      of: find.byType(TopBar),
      matching: find.byKey(const ValueKey('window-drag-region')),
    );
    // Берёмся за крошку «EVAPORATE / раздел»: она не орган управления, и
    // за имя приложения окно тянуться обязано.
    final grip = tester.getTopLeft(rail) + const Offset(60, 29);

    await tester.dragFrom(grip, const Offset(100, 0));
    await tester.pumpAndSettle();
    expect(calls.any((c) => c.method == 'startDragging'), isTrue);

    await tester.tapAt(grip);
    await tester.pump(const Duration(milliseconds: 70));
    await tester.tapAt(grip);
    await tester.pumpAndSettle();
    expect(maximized, isTrue);
  });

  // Взяться за окно у левого края — такое же ожидание, как у верхнего:
  // знак над разделами и пустое поле обоймы под ними тянут окно.
  testWidgets('обойма тянет окно за знак и пустое поле', (tester) async {
    await pumpApp(tester);
    final rack = find.byKey(const ValueKey('navigation-rack'));
    final column = tester.getRect(rack);

    for (final grip in [
      tester.getCenter(find.descendant(of: rack, matching: find.byType(Image))),
      Offset(column.center.dx, column.bottom - 40),
    ]) {
      calls.clear();
      await tester.dragFrom(grip, const Offset(0, 60));
      await tester.pumpAndSettle();
      expect(
        calls.any((c) => c.method == 'startDragging'),
        isTrue,
        reason: 'обойма не тянет окно из $grip',
      );
    }
  });

  testWidgets('край окна тянет ровно за свою сторону', (tester) async {
    await pump(tester);
    if (Platform.isMacOS) {
      // NSWindow handles resize; the plugin has no startResizing on macOS.
      expect(find.byKey(const ValueKey('window-resize-right')), findsNothing);
      expect(calls.any((c) => c.method == 'startResizing'), isFalse);
      return;
    }
    await tester.drag(
      find.byKey(const ValueKey('window-resize-right')),
      const Offset(-40, 0),
    );
    await tester.pumpAndSettle();
    final resize = calls.where((c) => c.method == 'startResizing').single;
    expect((resize.arguments as Map)['resizeEdge'], 'right');
  });

  // Рамка лежит выше Navigator, и это всё ещё верно для её полос: тянуть
  // окно за край можно и поверх открытого диалога. Клавиши окна этого
  // свойства лишились сознательно — они переехали в рейку, то есть под
  // барьер диалога, — и обменяно оно на то, что знак и название больше не
  // стоят в окне дважды.
  testWidgets('полосы изменения размера остаются над диалогом', (tester) async {
    if (Platform.isMacOS) return;
    await pump(tester);
    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    expect(find.text('Dialog'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('window-resize-right')),
      const Offset(-40, 0),
    );
    await tester.pumpAndSettle();
    expect(calls.any((c) => c.method == 'startResizing'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'системное разворачивание обновляет кнопки, а закрытие снимает слушателя',
    (tester) async {
      final before = windowManager.listeners.length;
      await pumpApp(tester);
      expect(windowManager.listeners.length, before + 1);
      final listener = windowManager.listeners.last;
      listener.onWindowMaximize();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Восстановить размер окна'), findsOneWidget);
      listener.onWindowUnmaximize();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Развернуть окно'), findsOneWidget);
      final clip = tester.widget<ClipRRect>(
        find.byKey(const ValueKey('window-clip')),
      );
      expect(
        clip.borderRadius,
        BorderRadius.circular(WindowChrome.cornerRadius),
      );
      await tester.pumpWidget(const SizedBox());
      expect(windowManager.listeners.length, before);
    },
  );

  testWidgets('подписи клавиш окна переводятся', (tester) async {
    await pumpApp(tester, locale: const Locale('en'));
    expect(find.byTooltip('Minimize window'), findsOneWidget);
    expect(find.byTooltip('Maximize window'), findsOneWidget);
  });

  // Отказ системы гасить нельзя: не свернувшееся по нажатию окно выглядит
  // зависшим, а объяснить, что случилось, кроме нас некому.
  testWidgets('отказ системы доходит сообщением, а нажать можно снова', (
    tester,
  ) async {
    await pumpApp(tester);
    failedMethod = 'minimize';
    await tester.tap(find.byTooltip('Свернуть окно'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.takeException(), isNull);

    failedMethod = null;
    calls.clear();
    await tester.tap(find.byTooltip('Свернуть окно'));
    await tester.pumpAndSettle();
    expect(calls.any((c) => c.method == 'minimize'), isTrue);
  });

  // Снимок — в двух окнах и с обложками: на пустой библиотеке не видно
  // главного, помещается ли первый ряд. Путь из переменной получает
  // размер окна перед расширением.
  for (final window in [const Size(900, 620), const Size(1280, 900)]) {
    final size = '${window.width.round()}x${window.height.round()}';
    testWidgets('в окне $size со своей рамкой библиотека помещается', (
      tester,
    ) async {
      final harness = TestHarness(tmp);
      addTearDown(harness.dispose);
      for (var i = 0; i < 8; i++) {
        harness.addGame(title: 'Игра $i');
      }
      tester.view.physicalSize = window;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        harness.buildApp(
          builder: (context, child) => RepaintBoundary(
            key: boundaryKey,
            child: AppWindowFrame(child: child!),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Библиотека ложится на диск через 400 мс после правки.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('rail-quit')), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Добавить игру'),
        findsOneWidget,
      );
      final preview = Platform.environment['WINDOW_FRAME_PREVIEW'];
      if (preview != null) {
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/branding/app_icon.png'),
            boundaryKey.currentContext!,
          ),
        );
        await tester.pumpAndSettle();
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File('${p.withoutExtension(preview)}-$size.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
      }
      expect(tester.takeException(), isNull);
    });
  }
}
