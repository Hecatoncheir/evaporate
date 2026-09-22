import 'package:tray_manager/tray_manager.dart';

import 'app_tray.dart';

/// Трей `tray_manager` 0.7 — `TrayIcon` из `nativeapi`.
///
/// Прежний API (`trayManager`, `TrayListener`) в 0.7 живёт в `legacy.dart`
/// и помечен устаревшим, то есть анализатор проекта его не пропускает.
/// Ссылки на значок и меню держатся полями: собранная сборщиком мусора
/// обёртка отпускает системный объект, и значок пропал бы сам.
class NativeTrayHost implements TrayHost {
  TrayIcon? _icon;
  Menu? _menu;

  @override
  void show({
    required String iconAsset,
    required String tooltip,
    required List<TrayEntry> menu,
    required void Function() onIconClick,
    required void Function(String id) onMenuSelected,
  }) {
    final icon = TrayIcon.create();
    final image = ImageAsset.fromAsset(iconAsset);
    if (icon == null || image == null) {
      icon?.dispose();
      throw StateError('трей недоступен: $iconAsset');
    }
    _icon = icon
      ..icon = image
      ..setTooltip(tooltip)
      // На Linux клики по значку система не сообщает — меню открывает
      // сама панель, и пункт «Открыть» там единственный путь к окну.
      ..setContextMenuTrigger(ContextMenuTrigger.rightClicked)
      ..addListener((event) {
        if (event is TrayIconClickedEvent) onIconClick();
      });
    setMenu(menu, onMenuSelected);
    if (!icon.setVisible(true)) {
      dispose();
      throw StateError('значок в трее не показался');
    }
  }

  @override
  void setMenu(List<TrayEntry> menu, void Function(String id) onMenuSelected) {
    final icon = _icon;
    final next = Menu.create();
    if (icon == null || next == null) return;
    for (final entry in menu) {
      final label = entry.label;
      if (label == null) {
        next.addSeparator();
        continue;
      }
      final item = MenuItem.createWithLabelAndType(label, MenuItemType.normal);
      item?.addListener((event) {
        if (event is MenuItemClickedEvent) onMenuSelected(entry.id);
      });
      next.addItem(item);
    }
    icon.setContextMenu(next);
    _menu?.dispose();
    _menu = next;
  }

  @override
  void dispose() {
    _icon?.dispose();
    _icon = null;
    _menu?.dispose();
    _menu = null;
  }
}
