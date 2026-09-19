import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'window_action.dart';
import 'window_chrome.dart';

/// Полоса у края окна.
///
/// Слушаем нажатие, а не жест перетаскивания, и вот почему: система по
/// нажатию забирает мышь себе и ведёт изменение размера сама, а Flutter
/// отпускания уже не видит. Жест так и остался бы незавершённым, да и
/// начинался бы он только после того, как палец уйдёт от точки нажатия на
/// два десятка точек, — то есть окно дёргалось бы скачком.
class WindowResizeZone extends StatelessWidget {
  const WindowResizeZone({super.key, required this.edge, required this.rect});

  final ResizeEdge edge;
  final Rect rect;

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: rect,
      child: MouseRegion(
        cursor: WindowChrome.cursorFor(edge),
        child: Listener(
          key: ValueKey('window-resize-${edge.name}'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            if (event.buttons != kPrimaryButton) return;
            unawaited(
              runWindowAction(context, () => windowManager.startResizing(edge)),
            );
          },
        ),
      ),
    );
  }
}
