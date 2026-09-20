import 'dart:async';

import 'package:evaporate/services/system/window_mode_watch.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Окна в прогоне нет, поэтому подменяем его там же, где это уже делает
/// проверка завершения, — на канале самого плагина.
void main() {
  const channel = MethodChannel('window_manager');

  late List<String> calls;
  late bool maximized;
  late bool fullScreen;

  /// Задержанный ответ окна: пока он не завершён, опрос висит.
  Completer<void>? hold;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    calls = [];
    maximized = false;
    fullScreen = false;
    hold = null;

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'isMaximized':
          await hold?.future;
          return maximized;
        case 'isFullScreen':
          await hold?.future;
          return fullScreen;
        case 'maximize':
          maximized = true;
        case 'unmaximize':
          maximized = false;
        case 'setFullScreen':
          fullScreen = (call.arguments as Map)['isFullScreen'] as bool;
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  });

  test('при запуске спрашивает у системы, как оно сейчас', () async {
    maximized = true;
    final watch = WindowModeWatch();

    await watch.attach();

    expect(watch.expanded.value, isTrue);
    watch.detach();
  });

  test('полный экран — тоже «развёрнуто»', () async {
    fullScreen = true;
    final watch = WindowModeWatch();

    await watch.attach();

    expect(watch.expanded.value, isTrue);
    watch.detach();
  });

  // Ради этого в рамке и жил трюк с номером правки: опрос идёт с
  // ожиданием, а событие приходит мгновенно. Отставший ответ рассказывает
  // о том, как было **до** события, и, записанный поверх, гасит окно,
  // которое человек только что развернул.
  test('ответ, отставший от события, не затирает свежее состояние', () async {
    final watch = WindowModeWatch();
    await watch.attach();

    hold = Completer<void>();
    final refresh = watch.refresh();
    watch.onWindowMaximize();
    expect(watch.expanded.value, isTrue);

    hold!.complete();
    await refresh;

    expect(watch.expanded.value, isTrue);
    watch.detach();
  });

  // Полноэкранный режим — тоже «развёрнуто», и выходить надо сначала из
  // него: иначе клавиша из полного экрана делала бы окно ещё и развёрнутым.
  test('из полного экрана клавиша выводит, а не разворачивает', () async {
    fullScreen = true;
    final watch = WindowModeWatch();
    await watch.attach();
    calls.clear();

    await watch.toggle();

    expect(calls, isNot(contains('maximize')));
    expect(calls, contains('setFullScreen'));
    expect(watch.expanded.value, isFalse);
    watch.detach();
  });

  test('обычное окно разворачивается, развёрнутое возвращается', () async {
    final watch = WindowModeWatch();
    await watch.attach();

    await watch.toggle();
    expect(watch.expanded.value, isTrue);

    await watch.toggle();
    expect(watch.expanded.value, isFalse);
    expect(calls, containsAllInOrder(['maximize', 'unmaximize']));
    watch.detach();
  });
}
