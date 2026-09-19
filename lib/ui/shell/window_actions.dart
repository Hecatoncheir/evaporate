import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../l10n/app_localizations.dart';
import '../widgets/window_action.dart';
import '../widgets/window_control.dart';
import 'top_action.dart';

/// Свернуть и развернуть окно.
///
/// Появляются, только когда рамку рисуем мы сами: с рамкой ОС эти клавиши
/// у окна уже есть, и вторых ему не нужно.
class WindowActions extends StatelessWidget {
  const WindowActions({super.key});

  @override
  Widget build(BuildContext context) {
    final control = WindowControl.maybeOf(context);
    if (control == null) return const SizedBox.shrink();

    final l = L.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TopAction(
          key: const ValueKey('rail-minimize'),
          tooltip: l.minimizeWindow,
          icon: Icons.remove,
          onPressed: () =>
              unawaited(runWindowAction(context, windowManager.minimize)),
        ),
        const SizedBox(width: 7),
        TopAction(
          key: const ValueKey('rail-maximize'),
          tooltip: control.expanded ? l.restoreWindow : l.maximizeWindow,
          icon: control.expanded ? Icons.filter_none : Icons.crop_square,
          onPressed: () => unawaited(control.toggleSize()),
        ),
        const SizedBox(width: 7),
      ],
    );
  }
}
