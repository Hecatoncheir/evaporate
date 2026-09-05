import 'dart:async';
import 'dart:ui';

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
  WindowCloseHandler(this._shutdown, {WindowManager? window})
    : _window = window ?? windowManager;

  final AppShutdown _shutdown;
  final WindowManager _window;

  Future<void> attach() async {
    _window.addListener(this);
    await _window.setPreventClose(true);
  }

  @override
  void onWindowClose() => unawaited(quit());

  Future<void> quit() async {
    await _shutdown.run();
    await _window.destroy();
  }
}
