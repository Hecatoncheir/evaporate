import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import 'app_shutdown.dart';
import 'window_state.dart';

/// Настоящее окно приложения.
///
/// Тонкая обёртка нужна затем, чтобы [WindowState] не зависел от плагина:
/// логику восстановления так можно проверить тестами, а окно в тестовой
/// среде не создать.
class ManagedWindowController implements WindowController {
  const ManagedWindowController();

  @override
  Future<Rect> getBounds() => windowManager.getBounds();

  @override
  Future<void> setBounds(Rect bounds) => windowManager.setBounds(bounds);

  @override
  Future<bool> isMaximized() => windowManager.isMaximized();

  @override
  Future<void> maximize() => windowManager.maximize();

  @override
  Future<void> unmaximize() => windowManager.unmaximize();

  @override
  Future<void> show() => windowManager.show();
}

/// Запоминает положение окна, пока пользователь его двигает.
class WindowStateSaver with WindowListener {
  WindowStateSaver(this._state);

  final WindowState _state;
  Timer? _debounce;

  void attach() => windowManager.addListener(this);

  void detach() {
    _debounce?.cancel();
    windowManager.removeListener(this);
  }

  /// Перетаскивание окна сыплет событиями десятками в секунду, поэтому
  /// пишем на диск только когда движение затихло.
  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 500),
      () => unawaited(_state.save()),
    );
  }

  /// Дописать положение окна немедленно.
  ///
  /// Нужно при выходе: подвинуть окно и тут же закрыть приложение — обычное
  /// дело, а отложенная на полсекунды запись до диска в этом случае не
  /// доходит, и окно открывается на старом месте.
  Future<void> flush() async {
    final pending = _debounce?.isActive ?? false;
    _debounce?.cancel();
    if (pending) await _state.save();
  }

  @override
  void onWindowResized() => _schedule();

  @override
  void onWindowMoved() => _schedule();

  @override
  void onWindowMaximize() => _schedule();

  @override
  void onWindowUnmaximize() => _schedule();
}

/// Проводит закрытие окна через [AppShutdown], а не мимо него.
///
/// Без `setPreventClose` нажатие «Закрыть» убивает процесс сразу, и отложенные
/// записи на диск до него не доходят. Тем же путём уходит и «Выход» из трея:
/// два способа выйти — одно завершение.
class WindowCloseHandler with WindowListener {
  WindowCloseHandler(
    this._shutdown, {
    WindowManager? window,
    @visibleForTesting void Function(int code)? exitProcess,
    @visibleForTesting String? platform,
  }) : _window = window ?? windowManager,
       _exit = exitProcess ?? exit,
       _os = platform ?? Platform.operatingSystem;

  final AppShutdown _shutdown;
  final WindowManager _window;
  final void Function(int code) _exit;
  final String _os;

  Future<void> attach() async {
    _window.addListener(this);
    await _window.setPreventClose(true);
  }

  @override
  void onWindowClose() => unawaited(quit());

  /// Дописывает несделанное и заканчивает процесс.
  ///
  /// На Windows — своими руками, а не разрушением окна. Штатный путь
  /// (`destroy()` — это `PostQuitMessage`) разбирает движок Flutter, пока в
  /// него ещё стучатся чужие потоки: опрос геймпада, уведомления, задачи
  /// движка загрузок. Процесс от этого падает внутри `flutter_windows.dll`
  /// по одному и тому же адресу, и человек видит это окном «программа
  /// перестала работать» после каждого закрытия.
  ///
  /// Терять тут нечего: всё, что должно лечь на диск, уже легло — шаги
  /// завершения отработали строкой выше, и именно ради них закрытие
  /// перехвачено. Разбирать движок после этого не нужно никому.
  ///
  /// Окно прячется первым делом: завершение идёт до восьми секунд, и всё
  /// это время окно оставалось на экране и нажималось — второе «Закрыть»
  /// было самым естественным ответом на «оно не закрывается».
  Future<void> quit() async {
    if (!_shutdown.isStarted) {
      try {
        await _window.hide();
      } on Object {
        // Спрятать не вышло — завершать это не мешает.
      }
    }
    await _shutdown.run();
    if (_os == 'windows') {
      _exit(0);
      return;
    }
    await _window.destroy();
  }
}
