import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../window/window_action.dart';
import '../window/window_control.dart';

/// Подложка, за которую таскают окно. Двойное нажатие по ней разворачивает
/// окно — так же, как по заголовку обычного окна системы.
///
/// Пуста, если своей рамки нет: окном тогда распоряжается система, и
/// перехватывать её жесты нельзя.
class WindowDragArea extends StatelessWidget {
  const WindowDragArea({super.key});

  @override
  Widget build(BuildContext context) {
    final control = WindowControl.maybeOf(context);
    if (control == null) return const SizedBox.shrink();

    return GestureDetector(
      key: const ValueKey('window-drag-region'),
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) =>
          unawaited(runWindowAction(context, windowManager.startDragging)),
      onDoubleTap: () => unawaited(control.toggleSize()),
      child: const SizedBox.expand(),
    );
  }
}
