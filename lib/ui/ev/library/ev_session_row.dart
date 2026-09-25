import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../art/ev_art.dart';
import '../art/key_art.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../glass/ev_glass.dart';
import '../widgets/ev_focusable.dart';
import '../widgets/ev_icon.dart';

/// Строка «Продолжить»: обложка 46 × 60, название, сколько сыграно
/// и когда, и круглая кнопка запуска справа. При наведении строка
/// уезжает на 3 px вправо, а кнопка разгорается.
class EvSessionRow extends StatefulWidget {
  const EvSessionRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.palette,
    required this.seed,
    this.onTap,
  });

  final String title;

  /// «6 ч · вчера в 23:40».
  final String subtitle;

  final EvCoverPalette palette;
  final int seed;

  /// `null` — действия пока нет: строка откликается на наведение, но фокус
  /// не получает. Откроет карточку игры, когда та появится.
  final VoidCallback? onTap;

  @override
  State<EvSessionRow> createState() => _EvSessionRowState();
}

class _EvSessionRowState extends State<EvSessionRow> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final lit = _hover || _focus;
    const duration = Duration(milliseconds: 260);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: EvFocusable(
        onActivate: widget.onTap,
        radius: ev.radii.r3,
        onFocusHighlight: (value) => setState(() => _focus = value),
        child: AnimatedContainer(
          duration: duration,
          curve: EvMotion.ease,
          transform: Matrix4.translationValues(lit ? 3 : 0, 0, 0),
          child: EvGlass(
            // Строки одной сетки читают фон один раз на всех.
            grouped: true,
            style: EvGlassStyle.frost.copyWith(blur: 16, tintAlpha: 0.4),
            borderRadius: ev.radii.b3,
            tint: c.surface.withValues(alpha: lit ? 0.52 : 0.4),
            padding: const EdgeInsets.all(11),
            child: Row(
              children: [
                _Thumb(palette: widget.palette, seed: widget.seed),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ev.text.title.copyWith(fontSize: 13.5),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ev.text.data.copyWith(
                          fontSize: 10.5,
                          color: c.ink4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 13),
                // Кружок запуска лежит на стекле строки: свой фон
                // читать незачем, а свет на кромке у него свой.
                EvGlass(
                  style: EvGlassStyle.chip,
                  backdrop: false,
                  borderRadius: BorderRadius.circular(
                    math.min(ev.radii.pill, 16),
                  ),
                  keyLight: lit ? c.hot2 : null,
                  tint: lit
                      ? c.hot1.withValues(alpha: 0.14)
                      : c.ink.withValues(alpha: 0.04),
                  shadows: lit
                      ? [
                          BoxShadow(
                            color: c.hot1.withValues(alpha: .3),
                            blurRadius: 18,
                          ),
                        ]
                      : const [],
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Center(
                      child: EvIcon(
                        EvIcons.play,
                        size: 13,
                        color: lit ? c.hot2 : c.ink3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.palette, required this.seed});

  final EvCoverPalette palette;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    return Container(
      width: 46,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: ev.radii.b4,
        border: Border.all(color: ev.colors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(math.max(0, ev.radii.r4 - 1)),
        child: EvCover(palette: palette, seed: seed),
      ),
    );
  }
}

/// Строки «Продолжить» колонками `repeat(auto-fill, minmax(268px, 1fr))`:
/// столько колонок не уже [minWidth], сколько помещается, пустые остаются
/// пустыми.
class EvSessionGrid extends StatelessWidget {
  const EvSessionGrid({
    super.key,
    required this.minWidth,
    required this.children,
  });

  final double minWidth;
  final List<Widget> children;

  static const gap = 12.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final columns = math.max(
        1,
        ((box.maxWidth + gap) / (minWidth + gap)).floor(),
      );
      final width = (box.maxWidth - gap * (columns - 1)) / columns;
      // Строки не перекрываются и лежат на одном фоне — один снимок
      // на всю сетку.
      return BackdropGroup(
        child: Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        ),
      );
    },
  );
}
