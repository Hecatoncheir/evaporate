import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

/// Развёрнуто ли окно — развёрнутым или во весь экран.
///
/// Это был третий слушатель окна, и жил он прямо в рамке: два поля, трюк с
/// номером правки против гонок и опрос системы из `initState`. Проверить
/// его там было нечем — настоящего окна в прогоне нет, — а ошибиться легко:
/// опрос идёт с ожиданием, событие может прийти раньше ответа, и тогда
/// ответ затирает свежее состояние прежним.
///
/// Здесь то же самое, но с подменяемым окном и без виджета: рамке остаётся
/// подписаться и рисовать.
class WindowModeWatch with WindowListener {
  WindowModeWatch({WindowManager? window}) : _window = window ?? windowManager;

  final WindowManager _window;

  /// Развёрнуто ли окно. Рамке достаточно этого: углы она режет и полосы
  /// размера показывает не отдельно «развёрнутому» и «полноэкранному».
  final ValueNotifier<bool> expanded = ValueNotifier<bool>(false);

  bool _maximized = false;
  bool _fullScreen = false;

  /// Сколько событий пришло. Ответ на опрос, отставший от события,
  /// выбрасывается: он рассказывает о том, как было до него.
  int _revision = 0;

  Future<void> attach() async {
    _window.addListener(this);
    await refresh();
  }

  void detach() {
    _window.removeListener(this);
    expanded.dispose();
  }

  /// Спрашивает у системы, как оно сейчас.
  ///
  /// Нужен не только при запуске: на части систем событие о развороте
  /// приходит с задержкой, и клавиша до него показывала бы несбывшееся.
  Future<void> refresh() async {
    final revision = _revision;
    final values = await Future.wait([
      _window.isMaximized(),
      _window.isFullScreen(),
    ]);
    if (revision != _revision) return;
    _maximized = values[0];
    _fullScreen = values[1];
    _publish();
  }

  /// Разворачивает окно или возвращает прежний размер.
  ///
  /// Полноэкранный режим — тоже «развёрнуто», и выходим сначала из него:
  /// иначе клавиша из полного экрана делала бы окно ещё и развёрнутым.
  Future<void> toggle() async {
    if (await _window.isFullScreen()) {
      await _window.setFullScreen(false);
    } else if (await _window.isMaximized()) {
      await _window.unmaximize();
    } else {
      await _window.maximize();
    }
    await refresh();
  }

  void _set({bool? maximized, bool? fullScreen}) {
    _revision++;
    _maximized = maximized ?? _maximized;
    _fullScreen = fullScreen ?? _fullScreen;
    _publish();
  }

  void _publish() => expanded.value = _maximized || _fullScreen;

  @override
  void onWindowMaximize() => _set(maximized: true);

  @override
  void onWindowUnmaximize() => _set(maximized: false);

  @override
  void onWindowEnterFullScreen() => _set(fullScreen: true);

  @override
  void onWindowLeaveFullScreen() => _set(fullScreen: false);
}
