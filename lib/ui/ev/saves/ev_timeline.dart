import 'package:flutter/widgets.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../widgets/ev_icon.dart';
import '../widgets/ev_surfaces.dart';
import '../widgets/ev_thread.dart';
import 'saves_data.dart';

/// Метка устройства или состояния точки: таблетка с контуром. Зелёная —
/// ушло, жёлтая — требует решения; всё остальное без цвета, потому что
/// «откуда» — это не событие.
class EvDeviceChip extends StatelessWidget {
  const EvDeviceChip({
    super.key,
    this.icon,
    required this.label,
    this.tone,
    this.bare = false,
  });

  final String? icon;
  final String label;

  /// Цвет причины: `EvColors.ok` — синхронно, `EvColors.warn` — решение.
  final Color? tone;

  /// Без рамки: приписка в конце строки, не метка.
  final bool bare;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final style = ev.text.data.copyWith(
      fontSize: 10.5,
      color: tone ?? (bare ? c.ink4 : c.ink3),
    );
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          EvIcon(icon!, size: 12, color: style.color),
          const SizedBox(width: 7),
        ],
        Text(label, style: style),
      ],
    );
    if (bare) {
      return Padding(padding: const EdgeInsets.only(left: 2), child: row);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: ev.radii.bPill,
        border: Border.all(
          color: tone == null ? c.lineSoft : tone!.withValues(alpha: .33),
        ),
        color: tone?.withValues(alpha: .07),
      ),
      child: row,
    );
  }
}

/// Лента сохранений: точки на общей нити событий.
class EvSaveTimeline extends StatelessWidget {
  const EvSaveTimeline({super.key, required this.points});

  final List<EvSavePoint> points;

  @override
  Widget build(BuildContext context) => EvThread(
    children: [
      for (final (i, p) in points.indexed) EvSaveRow(point: p, now: i == 0),
    ],
  );
}

/// Точка ленты: где вы остановились, когда и куда это ушло.
class EvSaveRow extends StatelessWidget {
  const EvSaveRow({super.key, required this.point, this.now = false});

  final EvSavePoint point;

  /// Верхняя точка — та, что была только что.
  final bool now;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final p = point;
    return EvThreadRow(
      now: now,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    p.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ev.text.ui(ev.text.title, size: 13.5),
                  ),
                ),
                const SizedBox(width: 11),
                Text(
                  p.stamp,
                  style: ev.text.data.copyWith(fontSize: 10.5, color: c.ink4),
                ),
              ],
            ),
            if (p.progress != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: EvBar(p.progress!, cool: true),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                switch (p.mark) {
                  EvSaveMark.synced => const EvDeviceChip(
                    icon: EvIcons.cloud,
                    label: 'выгружено',
                    tone: EvColors.ok,
                  ),
                  EvSaveMark.conflict => const EvDeviceChip(
                    icon: EvIcons.merge,
                    label: 'конфликт версий',
                    tone: EvColors.warn,
                  ),
                  EvSaveMark.uploading => EvDeviceChip(
                    icon: EvIcons.cloud,
                    label: 'выгружается · ${(p.progress! * 100).round()} %',
                    tone: c.cool,
                  ),
                  EvSaveMark.waiting => const EvDeviceChip(
                    icon: EvIcons.cloud,
                    label: 'ждёт очереди',
                  ),
                },
                EvDeviceChip(icon: p.device.icon, label: p.device.short),
                EvDeviceChip(label: p.note, bare: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
