import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/game_facts.dart';
import '../design/theme.dart';
import '../widgets/ev_focusable.dart';
import '../widgets/ev_icon.dart';

/// Часть раздачи с галочкой: озвучка, текстуры, саундтрек. Обязательную
/// не снять. Одна и та же строка в карточке игры и в диалоге добавления.
class EvPartRow extends StatefulWidget {
  const EvPartRow({
    super.key,
    required this.part,
    required this.on,
    required this.onToggle,
  });

  final EvGamePart part;
  final bool on;
  final VoidCallback? onToggle;

  @override
  State<EvPartRow> createState() => _EvPartRowState();
}

class _EvPartRowState extends State<EvPartRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final on = widget.on;
    return MouseRegion(
      cursor: widget.onToggle == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = widget.onToggle != null),
      onExit: (_) => setState(() => _hover = false),
      child: EvFocusable(
        onActivate: widget.onToggle,
        radius: ev.radii.r2,
        child: Semantics(
          button: widget.onToggle != null,
          checked: on,
          label: widget.part.name,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: widget.onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: ev.radii.b2,
                color: _hover ? c.ink.withValues(alpha: .04) : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 17,
                    height: 17,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        math.min(5, ev.radii.r2),
                      ),
                      border: Border.all(color: on ? c.hot1 : c.line),
                      gradient: on
                          ? LinearGradient(
                              begin: const Alignment(-.7, -1),
                              end: const Alignment(.7, 1),
                              colors: [c.hot2, c.hot1],
                            )
                          : null,
                      boxShadow: on
                          ? [
                              BoxShadow(
                                color: c.hot1.withValues(alpha: .5),
                                blurRadius: 14,
                              ),
                            ]
                          : null,
                    ),
                    child: on
                        ? const Center(
                            child: EvIcon(
                              EvIcons.verified,
                              size: 11,
                              color: Color(0xFF1A0A00),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.part.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ev.text.body.copyWith(
                              fontSize: 13,
                              color: on ? c.ink : c.ink4,
                            ),
                          ),
                        ),
                        if (widget.part.required) ...[
                          const SizedBox(width: 8),
                          Text(
                            'обязательно',
                            style: ev.text.data.copyWith(
                              fontSize: 10,
                              color: c.ink4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 11),
                  Text(
                    formatGb(widget.part.size),
                    style: ev.text.data.copyWith(
                      fontSize: 11.5,
                      color: on ? c.ink2 : c.ink4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
