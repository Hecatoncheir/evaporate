import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/ev_art.dart';
import '../atmosphere/ev_atmosphere.dart';
import '../design/theme.dart';
import '../sound/ev_sound.dart';
import '../sound/voices.dart';
import '../design/tokens.dart';
import '../glass/ev_glass.dart';
import '../widgets/ev_controls.dart';
import '../widgets/ev_icon.dart';
import 'return_data.dart';

/// Точка сохранения: миниатюра, место, когда и сколько, ушла ли
/// в облако. Под кнопкой героя — с «Другое», в карточке игры — без.
class EvSavePointCard extends StatelessWidget {
  const EvSavePointCard({super.key, required this.spot, this.onOther});

  final EvSaveSpot spot;

  /// «Другое» — выбрать другую точку. `null` — кнопки нет.
  final VoidCallback? onOther;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final s = spot;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: EvGlass(
        style: EvGlassStyle.lens,
        borderRadius: ev.radii.b3,
        tint: const Color.fromRGBO(10, 11, 17, .66),
        padding: const EdgeInsets.fromLTRB(9, 9, 12, 9),
        child: Row(
          children: [
            SizedBox(
              width: 42,
              height: 32,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(math.min(7, ev.radii.r3)),
                child: EvCover(palette: s.game.palette, seed: s.game.seed),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Сохранение ${s.where}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ev.text.body.copyWith(fontSize: 12.5, color: c.ink),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      s.ago,
                      if (s.uploaded) 'выгружено' else 'ждёт выгрузки',
                      s.size,
                    ].join(' · '),
                    style: ev.text.data.copyWith(fontSize: 10, color: c.ink4),
                  ),
                ],
              ),
            ),
            if (onOther != null) ...[
              const SizedBox(width: 12),
              EvMiniButton(label: 'Другое', onPressed: onOther),
            ],
          ],
        ),
      ),
    );
  }
}

/// «Пока вас не было»: что изменилось за время отсутствия. Пять событий,
/// у каждого одна строка, одна подпись и не больше одного действия.
class EvDigest extends StatelessWidget {
  const EvDigest({
    super.key,
    required this.events,
    required this.onAction,
    required this.onDone,
  });

  final List<EvDigestEvent> events;
  final ValueChanged<EvDigestEvent> onAction;

  /// «Всё понятно» и крестик: дайджест испаряется в плашку.
  final VoidCallback onDone;

  static const width = 360.0;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final line = BorderSide(color: c.lineSoft);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: ev.radii.b4,
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, .66),
            blurRadius: 70,
            offset: Offset(0, 26),
          ),
        ],
      ),
      child: EvGlass(
        style: EvGlassStyle.raised,
        borderRadius: ev.radii.b4,
        tint: const Color.fromRGBO(14, 15, 22, .9),
        child: Semantics(
          container: true,
          label: 'Пока вас не было',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
                decoration: BoxDecoration(border: Border(bottom: line)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ПОКА ВАС НЕ БЫЛО',
                        style: ev.text.data.copyWith(
                          fontSize: 10,
                          letterSpacing: 1.8,
                          color: c.ink2,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: ev.radii.bPill,
                        border: Border.all(color: c.hot1.withValues(alpha: .4)),
                        color: c.hot1.withValues(alpha: .1),
                      ),
                      child: Text(
                        '${events.length}',
                        style: ev.text.data.copyWith(
                          fontSize: 10,
                          color: c.hot2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    EvIconButton(
                      icon: EvIcons.close,
                      label: 'Свернуть',
                      onPressed: onDone,
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, e) in events.indexed)
                        _DigestRow(
                          event: e,
                          last: i == events.length - 1,
                          onAction: () => onAction(e),
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(border: Border(top: line)),
                child: EvGhostButton(
                  label: 'Всё понятно',
                  icon: EvIcons.check,
                  height: 36,
                  onPressed: onDone,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DigestRow extends StatelessWidget {
  const _DigestRow({
    required this.event,
    required this.last,
    required this.onAction,
  });

  final EvDigestEvent event;
  final bool last;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final e = event;
    final tone = switch (e.tone) {
      EvDigestTone.ok => EvColors.ok,
      EvDigestTone.hot => c.hot2,
      EvDigestTone.arc => c.arc,
      EvDigestTone.warn => EvColors.warn,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: c.lineSoft)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(math.min(8, ev.radii.r2)),
              border: Border.all(color: tone.withValues(alpha: .4)),
              color: tone.withValues(alpha: .09),
            ),
            child: EvIcon(e.icon, size: 13, color: tone),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.title,
                  style: ev.text.body.copyWith(
                    fontSize: 12.8,
                    height: 1.35,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  e.detail,
                  style: ev.text.data.copyWith(fontSize: 10, color: c.ink4),
                ),
              ],
            ),
          ),
          if (e.action != null) ...[
            const SizedBox(width: 11),
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: EvMiniButton(label: e.action!, onPressed: onAction),
            ),
          ],
        ],
      ),
    );
  }
}

/// Место дайджеста. Когда он сворачивается — кнопкой «Всё понятно» или
/// шагом сценария, — панель испаряется: из её прямоугольника срываются
/// искры, а сама она уходит вверх и тает. Ритуал в миниатюре.
class EvDigestSlot extends StatefulWidget {
  const EvDigestSlot({
    super.key,
    required this.open,
    required this.events,
    required this.onAction,
    required this.onDone,
  });

  final bool open;
  final List<EvDigestEvent> events;
  final ValueChanged<EvDigestEvent> onAction;
  final VoidCallback onDone;

  @override
  State<EvDigestSlot> createState() => _EvDigestSlotState();
}

class _EvDigestSlotState extends State<EvDigestSlot> {
  final _panel = GlobalKey();

  @override
  void didUpdateWidget(EvDigestSlot old) {
    super.didUpdateWidget(old);
    if (old.open && !widget.open) _evaporate();
  }

  void _evaporate() {
    final box = _panel.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    // Звук не громче картинки: нет искр — нет и испарения.
    if (EvAtmosphere.burstFrom(context, rect)) {
      EvSoundScope.maybeOf(context)?.play(EvVoice.evaporate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduced ? Duration.zero : const Duration(milliseconds: 340),
      switchInCurve: EvMotion.easeOut,
      transitionBuilder: (child, t) => FadeTransition(
        opacity: t,
        child: AnimatedBuilder(
          animation: t,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, -16 * (1 - t.value)),
            child: Transform.scale(scale: .96 + .04 * t.value, child: child),
          ),
          child: child,
        ),
      ),
      child: widget.open
          ? EvDigest(
              key: _panel,
              events: widget.events,
              onAction: widget.onAction,
              onDone: widget.onDone,
            )
          : const SizedBox.shrink(key: ValueKey('folded')),
    );
  }
}
