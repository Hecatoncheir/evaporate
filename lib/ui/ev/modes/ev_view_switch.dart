import 'package:flutter/widgets.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../shell/ev_top_bar.dart';
import '../widgets/ev_focusable.dart';
import '../widgets/ev_icon.dart';
import 'modes_data.dart';

/// Переключатель видов библиотеки и кнопка «Пульт». Стоит в верхней
/// полосе рядом с крошкой и виден только на библиотеке.
class EvViewSwitch extends StatelessWidget {
  const EvViewSwitch({
    super.key,
    required this.view,
    required this.onView,
    required this.onPult,
  });

  final EvLibraryView view;
  final ValueChanged<EvLibraryView> onView;
  final VoidCallback onPult;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          container: true,
          label: 'Вид библиотеки',
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: ev.radii.bPill,
              border: Border.all(color: c.line),
              color: const Color.fromRGBO(0, 0, 0, .25),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, v) in EvLibraryView.values.indexed) ...[
                  if (i > 0) const SizedBox(width: 2),
                  _ViewButton(
                    view: v,
                    selected: v == view,
                    onTap: () => onView(v),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        _PultButton(onTap: onPult),
      ],
    );
  }
}

class _ViewButton extends StatefulWidget {
  const _ViewButton({
    required this.view,
    required this.selected,
    required this.onTap,
  });

  final EvLibraryView view;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ViewButton> createState() => _ViewButtonState();
}

class _ViewButtonState extends State<_ViewButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final color = widget.selected
        ? c.hot2
        : _hover
        ? c.ink2
        : c.ink4;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.view.label,
      excludeSemantics: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: EvFocusable(
          onActivate: widget.onTap,
          radius: ev.radii.pill,
          child: AnimatedContainer(
            duration: EvMotion.fast,
            width: 34,
            height: 26,
            decoration: BoxDecoration(
              borderRadius: ev.radii.bPill,
              color: widget.selected
                  ? c.ink.withValues(alpha: .1)
                  : const Color(0x00000000),
            ),
            child: Center(
              child: EvIcon(widget.view.icon, size: 15, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.kbtn` «Пульт · P».
class _PultButton extends StatefulWidget {
  const _PultButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_PultButton> createState() => _PultButtonState();
}

class _PultButtonState extends State<_PultButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final ink = _hover ? c.ink2 : c.ink3;
    return Semantics(
      button: true,
      label: 'Режим «Пульт», клавиша P',
      excludeSemantics: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: EvFocusable(
          onActivate: widget.onTap,
          radius: ev.radii.r2,
          child: AnimatedContainer(
            duration: EvMotion.fast,
            height: 34,
            padding: const EdgeInsets.only(left: 11, right: 10),
            decoration: BoxDecoration(
              borderRadius: ev.radii.b2,
              border: Border.all(color: _hover ? c.ink4 : c.line),
              color: c.ink.withValues(alpha: _hover ? .05 : .02),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                EvIcon(EvIcons.pad, size: 15, color: ink),
                const SizedBox(width: 9),
                Text('Пульт', style: ev.text.bodySmall.copyWith(color: ink)),
                const SizedBox(width: 9),
                const EvKey('P', dense: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
