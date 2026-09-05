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
    this.onQuit,
  }) : _tray = manager ?? trayManager,
       _window = window ?? windowManager,
       _localizations = localizations ?? _defaultLocalizations;

  /// Как выходить по пункту «Выход».
  ///
  /// Своими силами трей умеет только убить окно, а вместе с ним и процесс —
  /// мимо отложенных записей на диск. Приложение передаёт сюда то же
  /// завершение, через которое проходит закрытие окна; без него остаётся
  /// прежнее поведение, чтобы трей был работоспособен и сам по себе.
  final Future<void> Function()? onQuit;

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
    await _tray.setIcon(iconPath);
    // Подсказка нужна: значок мелкий, и по нему одному приложение не узнать.
    await _tray.setToolTip('Evaporate');
    await _tray.setContextMenu(buildMenu(_localizations()));
    _tray.addListener(this);
    _installed = true;
  }

  Future<void> updateMenu() async {
    if (!_installed) return;
    await _tray.setContextMenu(buildMenu(_localizations()));
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
        final quit = onQuit;
        if (quit == null) {
          _window.destroy();
        } else {
          quit();
        }
    }
  }
}
