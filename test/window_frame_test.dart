import 'dart:io';
import 'dart:ui' as ui;

import 'package:evaporate/l10n/app_localizations.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:evaporate/ui/widgets/window_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/window_manager.dart';

import 'support/test_app.dart';

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
      'Nunito': 'assets/fonts/Nunito.ttf',
      'Nunito Sans': 'assets/fonts/NunitoSans.ttf',
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

  testWidgets('minimize, maximize, restore and close call the OS', (
    tester,
  ) async {
    await pump(tester);
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
    await tester.tap(find.byTooltip('Закрыть окно'));
    await tester.pumpAndSettle();
    expect(calls.any((c) => c.method == 'close'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'startup maximized/fullscreen state has no resize edges or rounding',
    (tester) async {
      fullScreen = true;
      await pump(tester);
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

  testWidgets(
    'title dragging and double click preserve native window behavior',
    (tester) async {
      await pump(tester);
      final title = find.byKey(const ValueKey('window-drag-region'));
      await tester.drag(title, const Offset(100, 0));
      await tester.pumpAndSettle();
      expect(calls.any((c) => c.method == 'startDragging'), isTrue);
      await tester.tap(title);
      await tester.pump(const Duration(milliseconds: 70));
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(maximized, isTrue);
    },
  );

  testWidgets('resize edges call the matching native edge', (tester) async {
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

  testWidgets(
    'native maximize events update controls and dispose removes listener',
    (tester) async {
      final before = windowManager.listeners.length;
      await pump(tester);
      expect(windowManager.listeners.length, before + 1);
      final listener = windowManager.listeners.last;
      listener.onWindowMaximize();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Восстановить размер окна'), findsOneWidget);
      listener.onWindowUnmaximize();
      listener.onWindowBlur();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Развернуть окно'), findsOneWidget);
      final clip = tester.widget<ClipRRect>(
        find.byKey(const ValueKey('window-clip')),
      );
      expect(
        clip.borderRadius,
        BorderRadius.circular(Platform.isWindows ? 0 : 12),
      );
      await tester.pumpWidget(const SizedBox());
      expect(windowManager.listeners.length, before);
    },
  );

  testWidgets('window controls stay outside modal dialogs and are localized', (
    tester,
  ) async {
    await pump(tester, locale: const Locale('en'));
    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    expect(find.text('Dialog'), findsOneWidget);
    await tester.tap(find.byTooltip('Minimize window'));
    await tester.pumpAndSettle();
    expect(calls.any((c) => c.method == 'minimize'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('native operation errors are handled and can be retried', (
    tester,
  ) async {
    await pump(tester);
    failedMethod = 'minimize';
    await tester.tap(find.byTooltip('Свернуть окно'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(tester.takeException(), isNull);
    failedMethod = null;
    await tester.tap(find.byTooltip('Свернуть окно'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  testWidgets('library fits minimum window size with custom frame', (
    tester,
  ) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    tester.view.physicalSize = const Size(900, 620);
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
    expect(find.byTooltip('Закрыть окно'), findsOneWidget);
    expect(find.text('Найти установленные игры'), findsOneWidget);
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
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(preview).writeAsBytes(bytes!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
    }
    expect(tester.takeException(), isNull);
  });
}
