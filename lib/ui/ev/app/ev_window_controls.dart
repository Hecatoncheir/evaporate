import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../../l10n/app_localizations.dart';
import '../../window/window_action.dart';
import '../../window/window_control.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../glass/ev_glass.dart';
import '../widgets/ev_focusable.dart';
import '../widgets/ev_icon.dart';

/// Клавиши окна справа в верхней полосе: свернуть, развернуть, выключить.
///
/// Рамки системы у окна нет, поэтому клавиши рисуем сами. Свернуть и
/// развернуть — только при своей рамке ([WindowControl] выше по дереву):
/// с рамкой системы они у окна уже есть. «Выключить» есть всегда — и
/// закрывает окно, а не процесс: закрытие перехвачено, и по этому пути
/// отложенные записи успевают лечь на диск (`AppShutdown`).
class EvWindowControls extends StatelessWidget {
  const EvWindowControls({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final control = WindowControl.maybeOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        if (control != null) ...[
          _WindowKey(
            key: const ValueKey('rail-minimize'),
            tooltip: l.minimizeWindow,
            icon: (ink) => Icon(Icons.remove, size: 16, color: ink),
            onTap: () =>
                unawaited(runWindowAction(context, windowManager.minimize)),
          ),
          _WindowKey(
            key: const ValueKey('rail-maximize'),
            tooltip: control.expanded ? l.restoreWindow : l.maximizeWindow,
            icon: (ink) => Icon(
              control.expanded ? Icons.filter_none : Icons.crop_square,
              size: 14,
              color: ink,
            ),
            onTap: () => unawaited(control.toggleSize()),
          ),
        ],
        _WindowKey(
          key: const ValueKey('rail-quit'),
          tooltip: l.quitApp,
          danger: true,
          icon: (ink) => EvIcon(EvIcons.power, size: 15, color: ink),
          onTap: () => unawaited(windowManager.close()),
        ),
      ],
    );
  }
}

/// Клавиша окна: кусочек стекла, как поиск рядом, только квадратный.
/// «Выключить» краснеет под курсором, а не всегда: постоянно красная
/// клавиша в углу читалась бы как поломка.
class _WindowKey extends StatefulWidget {
  const _WindowKey({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final String tooltip;
  final Widget Function(Color ink) icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  State<_WindowKey> createState() => _WindowKeyState();
}

class _WindowKeyState extends State<_WindowKey> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final lit = widget.danger ? EvColors.bad : c.ink;
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: EvFocusable(
            onActivate: widget.onTap,
            radius: ev.radii.r2,
            child: EvGlass(
              style: EvGlassStyle.chip,
              backdrop: false,
              interactive: true,
              borderRadius: ev.radii.b2,
              tint: c.ink.withValues(alpha: _hover ? 0.08 : 0.04),
              child: SizedBox.square(
                dimension: 34,
                child: Center(child: widget.icon(_hover ? lit : c.ink3)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
