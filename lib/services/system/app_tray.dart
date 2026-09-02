import 'dart:io';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';

/// Значок в трее.
///
/// Нужен прежде всего ради запуска свёрнутым: приложение, стартовавшее вместе
/// с системой и не показавшее окна, иначе было бы ничем не открыть. Заодно
/// закрытое в трей окно позволяет догружать игры, не занимая панель задач.
class AppTray with TrayListener {
  AppTray({
    TrayManager? manager,
    WindowManager? window,
    L Function()? localizations,
  }) : _tray = manager ?? trayManager,
       _window = window ?? windowManager,
       _localizations = localizations ?? _defaultLocalizations;

  /// Меню трея живёт вне дерева виджетов, поэтому язык приходит функцией.
  final L Function() _localizations;

  static L _defaultLocalizations() => LRu();

  final TrayManager _tray;
  final WindowManager _window;

  bool _installed = false;

  /// Windows принимает в трее только `.ico`, остальные — обычный PNG.
  static String get iconPath => Platform.isWindows
      ? 'assets/branding/tray_icon.ico'
      : 'assets/branding/tray_icon.png';

  static Menu buildMenu(L l) => Menu(
    items: [
      MenuItem(key: 'show', label: l.trayOpen),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: l.trayQuit),
    ],
  );

  Future<void> install() async {
    if (_installed) return;
    _tray.addListener(this);
    await _tray.setIcon(iconPath);
    // Подсказка нужна: значок мелкий, и по нему одному приложение не узнать.
    await _tray.setToolTip('Evaporate');
    await _tray.setContextMenu(buildMenu(_localizations()));
    _installed = true;
  }

  Future<void> dispose() async {
    if (!_installed) return;
    _tray.removeListener(this);
    await _tray.destroy();
    _installed = false;
  }

  Future<void> reveal() async {
    await _window.show();
    await _window.focus();
  }

  @override
  void onTrayIconMouseDown() {
    // Левый клик по значку — самый ожидаемый способ вернуть окно.
    reveal();
  }

  @override
  void onTrayIconRightMouseDown() {
    _tray.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        reveal();
      case 'quit':
        _window.destroy();
    }
  }
}
