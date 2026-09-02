import 'dart:async';
import 'dart:ui';

import 'package:window_manager/window_manager.dart';

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

  @override
  void onWindowResized() => _schedule();

  @override
  void onWindowMoved() => _schedule();

  @override
  void onWindowMaximize() => _schedule();

  @override
  void onWindowUnmaximize() => _schedule();
}
