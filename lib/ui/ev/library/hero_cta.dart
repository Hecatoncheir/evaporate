import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../glass/ev_glass.dart';
import '../widgets/ev_controls.dart';
import '../widgets/ev_icon.dart';
import '../widgets/ev_surfaces.dart';
import 'hero_state.dart';

/// Строка под кнопкой: куда встанет установка, чего не будет без сети.
/// Цвет кодирует причину, а не громкость.
class EvCtaNote extends StatelessWidget {
  const EvCtaNote(this.note, {super.key});

  final EvHeroNote note;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final color = switch (note.tone) {
      EvNoteTone.plain => c.ink3,
      EvNoteTone.warn => EvColors.warn,
      EvNoteTone.bad => EvColors.bad,
      EvNoteTone.cool => c.cool,
    };
    return Semantics(
      liveRegion: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          EvIcon(note.icon, size: 14, color: color),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              note.text,
              style: ev.text.data.copyWith(fontSize: 11, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Прогресс установки на месте кнопки «Играть»: что распаковывается,
/// сколько осталось и чем это остановить.
class EvInstallBox extends StatelessWidget {
  const EvInstallBox(this.install, {super.key, this.onPause, this.onCancel});

  final EvInstallProgress install;
  final VoidCallback? onPause;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: EvGlass(
        style: EvGlassStyle.frost,
        borderRadius: ev.radii.b3,
        tint: const Color.fromRGBO(10, 11, 17, .72),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    install.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ev.text.ui(
                      ev.text.body,
                      weight: FontWeight.w500,
                      size: 13,
                      color: c.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(install.value * 100).round()} %',
                  style: ev.text.data.copyWith(fontSize: 13, color: c.hot2),
                ),
              ],
            ),
            const SizedBox(height: 9),
            EvBar(install.value),
            const SizedBox(height: 9),
            Text(
              install.detail,
              style: ev.text.data.copyWith(fontSize: 10.5, color: c.ink4),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                EvMiniButton(
                  label: 'Пауза',
                  icon: EvIcons.pause,
                  onPressed: onPause,
                ),
                const SizedBox(width: 8),
                EvMiniButton(
                  label: 'Отменить',
                  icon: EvIcons.close,
                  danger: true,
                  onPressed: onCancel,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Кнопка стала статусом: игра идёт, и лаунчер здесь ни при чём.
/// Зелёный вместо янтаря — запуск уже случился.
class EvRunningPill extends StatefulWidget {
  const EvRunningPill(
    this.time, {
    super.key,
    this.label = 'Идёт игра',
    this.height = 56,
    this.hot = false,
  });

  /// «01:04:12» у игры, «41 %» у установки.
  final String time;

  /// «Идёт игра», «Установка».
  final String label;

  final double height;

  /// Янтарный вариант: идёт установка, а не игра.
  final bool hot;

  @override
  State<EvRunningPill> createState() => _EvRunningPillState();
}

class _EvRunningPillState extends State<EvRunningPill>
    with SingleTickerProviderStateMixin {
  // `@keyframes pulse{50%{opacity:.35}}` — та же точка, что у «качается»
  // в полосе загрузок.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final accent = widget.hot ? ev.colors.hot2 : EvColors.ok;
    final radius = math.min(ev.radii.pill, widget.height / 2);
    return Semantics(
      label: '${widget.label} ${widget.time}',
      excludeSemantics: true,
      child: Container(
        height: widget.height,
        padding: const EdgeInsets.only(left: 20, right: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: accent.withValues(alpha: .45)),
          gradient: LinearGradient(
            begin: const Alignment(-0.9, -0.6),
            end: const Alignment(0.9, 0.6),
            colors: [
              accent.withValues(alpha: .14),
              accent.withValues(alpha: .05),
            ],
          ),
          boxShadow: [
            BoxShadow(color: accent.withValues(alpha: .18), blurRadius: 30),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _pulse.drive(Tween(begin: 1, end: .35)),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                  boxShadow: [BoxShadow(color: accent, blurRadius: 12)],
                ),
              ),
            ),
            const SizedBox(width: 13),
            Text(
              widget.label,
              style: ev.text.ui(
                ev.text.title,
                weight: FontWeight.w500,
                color: accent,
              ),
            ),
            const SizedBox(width: 13),
            Text(
              widget.time,
              style: ev.text.data.copyWith(
                fontSize: 13,
                color: accent.withValues(alpha: .75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
