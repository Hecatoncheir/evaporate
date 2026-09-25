import 'package:flutter/widgets.dart';

import '../art/ev_art.dart';
import '../art/key_art.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../glass/ev_glass.dart';
import '../sound/ev_sound.dart';
import '../sound/voices.dart';
import 'ev_focusable.dart';
import 'ev_surfaces.dart';

/// Состояние игры на полке.
enum EvGameState { ready, downloading, queued }

/// Карточка на полке. Единственное, что выходит из плоскости при наведении:
/// −8 px по Y, тень 26 → 54 и контур акцента.
class EvGameCard extends StatefulWidget {
  const EvGameCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.palette,
    required this.seed,
    this.state = EvGameState.ready,
    this.progress,
    this.badge,
    this.width = 178,
    this.onTap,
    this.cover,
    this.onActiveChanged,
  });

  final String title;
  final String subtitle;
  final EvCoverPalette palette;
  final int seed;
  final EvGameState state;

  /// 0…1, показывается полосой внизу обложки.
  final double? progress;

  final String? badge;
  final double width;
  final VoidCallback? onTap;

  /// Обложка вместо рисованной прототипа — с украшениями приложения.
  /// Получает, горит ли карточка (под курсором или в фокусе): фольга,
  /// наклон, искры и капли идут за этим, а кант, тень и блик рисует
  /// сама обложка, поэтому свои у карточки тогда не нужны.
  final Widget Function(BuildContext context, bool active)? cover;

  /// Карточка загорелась или погасла. Полка поднимает горящую над
  /// соседями: иначе соседняя, нарисованная позже, закрывала бы её искры.
  final ValueChanged<bool>? onActiveChanged;

  @override
  State<EvGameCard> createState() => _EvGameCardState();
}

class _EvGameCardState extends State<EvGameCard> {
  bool _hover = false;
  bool _focus = false;

  void _set({bool? hover, bool? focus}) {
    final was = _hover || _focus;
    setState(() {
      _hover = hover ?? _hover;
      _focus = focus ?? _focus;
    });
    final now = _hover || _focus;
    if (now != was) widget.onActiveChanged?.call(now);
  }

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    // Фокус с клавиатуры поднимает карточку так же, как наведение:
    // на полке, которую листают стрелками, иначе не видно, где ты.
    final lifted = _hover || _focus;
    // Наведение ловится снаружи сдвига: иначе поднятая карточка уходила бы
    // из-под курсора у нижней кромки и начинала мигать.
    return MouseRegion(
      onEnter: (_) {
        EvSoundScope.maybeOf(context)?.play(EvVoice.tick);
        _set(hover: true);
      },
      onExit: (_) => _set(hover: false),
      child: AnimatedContainer(
        duration: EvMotion.hover,
        curve: EvMotion.easeOut,
        width: widget.width,
        transform: Matrix4.translationValues(0, lifted ? -8 : 0, 0),
        child: EvFocusable(
          onActivate: widget.onTap,
          radius: ev.radii.r3,
          onFocusHighlight: (v) => _set(focus: v),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.cover case final cover?)
                AspectRatio(
                  aspectRatio: 3 / 4,
                  // Искры выходят за обложку: слой их не обрезает.
                  child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      cover(context, lifted),
                      if (widget.badge != null)
                        Positioned(
                          top: 9,
                          left: 9,
                          child: EvCoverBadge(
                            widget.badge!,
                            state: widget.state,
                          ),
                        ),
                      if (widget.progress != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: EvBar(widget.progress!, cool: true, height: 3),
                        ),
                    ],
                  ),
                )
              else
                AspectRatio(
                  aspectRatio: 3 / 4,
                  child: AnimatedContainer(
                    duration: EvMotion.hover,
                    curve: EvMotion.easeOut,
                    decoration: BoxDecoration(
                      borderRadius: ev.radii.b3,
                      border: Border.all(
                        color: lifted ? c.hot1.withValues(alpha: 0.4) : c.line,
                      ),
                      boxShadow: lifted
                          ? [
                              ...ev.shadowLift,
                              BoxShadow(
                                color: c.hot1.withValues(alpha: 0.3),
                                blurRadius: 42,
                              ),
                            ]
                          : ev.shadowRest,
                    ),
                    child: ClipRRect(
                      borderRadius: ev.radii.b3,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          EvCover(palette: widget.palette, seed: widget.seed),
                          // кромка, освещённая изнутри
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 1,
                            child: ColoredBox(
                              color: c.ink.withValues(alpha: 0.16),
                            ),
                          ),
                          if (widget.badge != null)
                            Positioned(
                              top: 9,
                              left: 9,
                              child: EvCoverBadge(
                                widget.badge!,
                                state: widget.state,
                              ),
                            ),
                          if (widget.progress != null)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: EvBar(
                                widget.progress!,
                                cool: true,
                                height: 3,
                              ),
                            ),
                          if (lifted)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        const Color(0x00FFFFFF),
                                        c.ink.withValues(alpha: 0.22),
                                        const Color(0x00FFFFFF),
                                      ],
                                      stops: const [0.3, 0.48, 0.62],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 11),
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ev.text.ui(
                  ev.text.body,
                  weight: FontWeight.w500,
                  size: 13,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ev.text.data.copyWith(color: c.ink4, fontSize: 10.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Бейдж на обложке: процент загрузки, «в очереди», «новое». Общий
/// для полки и «Стены».
class EvCoverBadge extends StatelessWidget {
  const EvCoverBadge(this.label, {super.key, required this.state});

  final String label;
  final EvGameState state;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final tint = switch (state) {
      EvGameState.downloading => c.cool,
      EvGameState.queued => c.ink3,
      EvGameState.ready => c.hot2,
    };
    // Бейдж лежит прямо на обложке — линза, а не плашка: кадр под ним
    // виден и гнётся у кромки.
    return EvGlass(
      style: EvGlassStyle.lens.copyWith(blur: 10, bevel: 7, depth: 4),
      borderRadius: ev.radii.b1,
      keyLight: state == EvGameState.queued ? null : tint,
      tint: state == EvGameState.queued
          ? c.ground.withValues(alpha: 0.55)
          : tint.withValues(alpha: 0.16),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      child: Text(
        label.toUpperCase(),
        style: ev.text.data.copyWith(
          color: state == EvGameState.queued ? c.ink2 : tint,
          fontSize: 9.5,
          letterSpacing: 0.95,
        ),
      ),
    );
  }
}
