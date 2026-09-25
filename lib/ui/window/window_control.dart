import 'dart:async';

import 'package:flutter/material.dart';

/// Что верхней полосе каркаса нужно знать об окне: развёрнуто ли оно и как это
/// изменить.
///
/// Раздаётся сверху, от рамки, а не спрашивается у системы второй раз: два
/// независимых слушателя одного события — два места, где состояние может
/// разойтись, и разойтись им ничего не мешает.
///
/// Отсутствие этого виджета означает, что своей рамки нет вовсе, — тогда
/// полосе и нечего показывать: окном распоряжается система.
class WindowControl extends InheritedWidget {
  const WindowControl({
    super.key,
    required this.expanded,
    required this.toggleSize,
    required super.child,
  });

  /// Развёрнуто на весь экран или растянуто во весь рабочий стол.
  final bool expanded;

  final Future<void> Function() toggleSize;

  static WindowControl? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WindowControl>();

  @override
  bool updateShouldNotify(WindowControl oldWidget) =>
      oldWidget.expanded != expanded;
}
