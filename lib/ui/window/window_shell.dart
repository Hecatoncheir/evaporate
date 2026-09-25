import 'dart:io';

import 'package:flutter/material.dart';

import 'window_action.dart';
import 'window_chrome.dart';
import 'window_control.dart';
import 'window_resize_zone.dart';

/// Сама форма окна: срезанные углы, полосы для изменения размера и
/// клавиши управления поверх содержимого.
class WindowShell extends StatelessWidget {
  const WindowShell({
    super.key,
    required this.expanded,
    required this.onToggleSize,
    required this.child,
  });

  /// Развёрнуто ли окно — развёрнутым или во весь экран.
  final bool expanded;

  final Future<void> Function() onToggleSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Углы режем сами, на всех системах одинаково: фон окна прозрачный,
    // поэтому за вырезанным углом виден рабочий стол, а не подложка окна.
    // Развёрнутому окну углы не нужны: там их резать не от чего.
    final radius = expanded ? 0.0 : WindowChrome.cornerRadius;

    // Развёрнутому окну край тянуть незачем, а macOS меняет размер сама:
    // startResizing там не поддерживается.
    final resizable = !expanded && !Platform.isMacOS;

    return ClipRRect(
      key: const ValueKey('window-clip'),
      borderRadius: BorderRadius.circular(radius),
      // Панель находится выше Navigator и нуждается в своём Overlay
      // для подсказок. Он также обрезается по внешней форме окна.
      child: Overlay.wrap(
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            fit: StackFit.expand,
            children: [
              WindowControl(
                expanded: expanded,
                toggleSize: () => runWindowAction(context, onToggleSize),
                child: child,
              ),
              // Невидимые узкие полосы возвращают изменение размера после
              // удаления рамки ОС. Их размеры и правило «не накрывать
              // клавиш» живут в WindowChrome, где их и проверяет тест.
              if (resizable)
                for (final zone in WindowChrome.resizeZones(
                  constraints.biggest,
                ))
                  WindowResizeZone(edge: zone.edge, rect: zone.rect),
            ],
          ),
        ),
      ),
    );
  }
}
