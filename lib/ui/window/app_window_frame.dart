import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/system/window_mode_watch.dart';
import 'window_shell.dart';

/// Обрамляет весь Navigator, включая диалоги: рамки ОС нет, и скруглённые
/// углы с полосами для изменения размера рисуем мы сами.
///
/// Своей полосы заголовка у рамки нет — перетаскивание и клавиши окна живут
/// в верхней полосе каркаса, чтобы знак и название не стояли на экране
/// дважды. Цена решения: пока открыт модальный диалог, они под его
/// барьером.
class AppWindowFrame extends StatefulWidget {
  const AppWindowFrame({super.key, required this.child, this.mode});

  final Widget child;

  /// Кто следит за развёрнутостью окна. Свой заводится, только когда рамку
  /// поднимают в одиночку: в приложении он один на всех.
  final WindowModeWatch? mode;

  @override
  State<AppWindowFrame> createState() => _AppWindowFrameState();
}

class _AppWindowFrameState extends State<AppWindowFrame> {
  late final WindowModeWatch _mode = widget.mode ?? WindowModeWatch();
  late final bool _ownsMode = widget.mode == null;

  @override
  void initState() {
    super.initState();
    if (_ownsMode) unawaited(_mode.attach());
  }

  @override
  void dispose() {
    if (_ownsMode) _mode.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: _mode.expanded,
    builder: (context, expanded, _) => WindowShell(
      expanded: expanded,
      onToggleSize: _mode.toggle,
      child: widget.child,
    ),
  );
}
