import 'package:flutter/material.dart';

import 'rack_navigation.dart';
import 'shell_panel.dart';

/// Раскладка окна: обойма разделов слева, рядом — панель, в которой живут
/// разделы вместе с верхней рейкой и строкой подсказок.
class ShellLayout extends StatelessWidget {
  const ShellLayout({super.key});

  /// Ниже этой ширины поля ужимаются: каждая точка нужна содержимому.
  static const _compactWidth = 980.0;

  /// Ниже этой высоты строка подсказок убирается совсем — иначе не
  /// остаётся места самим разделам.
  static const _shortHeight = 520.0;

  /// Поле между краем окна и содержимым: в узком окне меньше, каждая точка
  /// ширины там нужна содержимому.
  ///
  /// Не приватное, потому что от него зависит чужое правило: полоса
  /// изменения размера у края окна не должна доставать до обоймы и
  /// верхней рейки, иначе нажатие на их клавишу уйдёт в системный цикл
  /// изменения размера. Здесь, а не у `AppShell`: применяет их раскладка.
  static const compactInset = 6.0;
  static const wideInset = 10.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final inset = box.maxWidth < _compactWidth ? compactInset : wideInset;
        return Padding(
          padding: EdgeInsets.all(inset),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const RackNavigation(),
              // Просвет между обоймой и панелью — то же поле, что у края
              // окна: две панели корпуса стоят на одном расстоянии от всего.
              SizedBox(width: inset),
              Expanded(child: ShellPanel(hints: box.maxHeight >= _shortHeight)),
            ],
          ),
        );
      },
    );
  }
}
