import 'dart:async';
import 'dart:io';

import 'package:window_manager/window_manager.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';

/// Пункт меню трея: `id` — что делать по нажатию, `label` — что написано.
/// Без подписи — разделитель.
typedef TrayEntry = ({String id, String? label});

/// Значок в трее.
///
/// Нужен прежде всего ради запуска свёрнутым: приложение, стартовавшее вместе
/// с системой и не показавшее окна, иначе было бы ничем не открыть. Заодно
/// закрытое в трей окно позволяет догружать игры, не занимая панель задач.
///
/// Меню задано данными ([menuEntries]), а нажатие — именем пункта
/// ([onMenuSelected]): то и другое проверяется без системного трея, которого
/// в тестах нет. Сам трей — [TrayHost].
class AppTray {
  AppTray({
    required this.host,
    WindowManager? window,
    L Function()? localizations,
    this.onQuit,
  }) : _window = window ?? windowManager,
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

  /// Системный трей: в приложении — `NativeTrayHost`, в тестах — подделка.
  final TrayHost host;
  final WindowManager _window;

  bool _installed = false;

  /// Стоит ли значок: дымовой запуск проверяет, что трей встал.
  bool get isInstalled => _installed;

  /// Файл значка из ассетов приложения.
  ///
  /// На Windows — `.ico`: он несёт несколько размеров сразу, и значок не
  /// мылится при масштабе экрана 150 %. Остальным хватает PNG.
  static String get iconPath => Platform.isWindows
      ? 'assets/branding/tray_icon.ico'
      : 'assets/branding/tray_icon.png';

  static List<TrayEntry> menuEntries(L l) => [
    (id: 'show', label: l.trayOpen),
    (id: 'separator', label: null),
    (id: 'quit', label: l.trayQuit),
  ];

  Future<void> install() async {
    if (_installed) return;
    host.show(
      iconAsset: iconPath,
      // Подсказка нужна: значок мелкий, и по нему одному приложение не узнать.
      tooltip: 'Evaporate',
      menu: menuEntries(_localizations()),
      // Левый клик по значку — самый ожидаемый способ вернуть окно.
      onIconClick: () => unawaited(reveal()),
      onMenuSelected: onMenuSelected,
    );
    _installed = true;
  }

  Future<void> updateMenu() async {
    if (!_installed) return;
    host.setMenu(menuEntries(_localizations()), onMenuSelected);
  }

  Future<void> dispose() async {
    if (!_installed) return;
    host.dispose();
    _installed = false;
  }

  Future<void> reveal() async {
    await _window.show();
    await _window.focus();
  }

  /// Нажат пункт меню. Колбэки трея синхронны: ждать здесь некому.
  void onMenuSelected(String id) {
    switch (id) {
      case 'show':
        unawaited(reveal());
      case 'quit':
        final quit = onQuit;
        if (quit == null) {
          unawaited(_window.destroy());
        } else {
          unawaited(quit());
        }
    }
  }
}

/// Системный трей: значок, подсказка и меню.
abstract class TrayHost {
  /// Показывает значок. Не вышло — бросает: приложение тогда показывает
  /// окно, иначе свёрнутое при запуске было бы ничем не открыть.
  void show({
    required String iconAsset,
    required String tooltip,
    required List<TrayEntry> menu,
    required void Function() onIconClick,
    required void Function(String id) onMenuSelected,
  });

  /// Заменяет меню: добавить или убрать пункты можно только новым меню.
  void setMenu(List<TrayEntry> menu, void Function(String id) onMenuSelected);

  void dispose();
}
