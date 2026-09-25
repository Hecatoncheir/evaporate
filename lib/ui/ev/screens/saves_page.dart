import 'package:flutter/widgets.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../saves/ev_conflict.dart';
import '../saves/ev_timeline.dart';
import '../saves/saves_data.dart';
import '../util/plural.dart';
import '../widgets/ev_controls.dart';
import '../widgets/ev_icon.dart';
import '../widgets/ev_surfaces.dart';

/// Сохранения — то, что нельзя потерять.
///
/// Сверху два прибора: сколько занято в облаке и где это лежит. Ниже —
/// расхождение, если его нужно разрешить, и лента точек: где вы были,
/// когда и с какого устройства. Расхождение стоит выше ленты, потому что
/// это единственное место раздела, где от человека чего-то ждут.
class SavesPage extends StatelessWidget {
  const SavesPage({
    super.key,
    required this.saves,
    this.onResolve,
    this.onRetry,
  });

  final EvSaves saves;

  /// Конфликт разрешён — любым из трёх способов.
  final VoidCallback? onResolve;

  /// Проверить связь с облаком.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final window = MediaQuery.sizeOf(context);
    final gutter = EvSpace.gutterFor(window);
    final chrome = MediaQuery.paddingOf(context);
    final s = saves;

    Widget section(String title, String count, Widget child) => Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EvSectionHeader(title, count: count),
          const SizedBox(height: EvSpace.l),
          child,
        ],
      ),
    );

    return ListView(
      primary: true,
      padding: EdgeInsets.fromLTRB(
        gutter,
        chrome.top + gutter,
        gutter,
        26 + chrome.bottom,
      ),
      children: [
        EvHeadPanels(
          left: _CloudPanel(saves: s),
          right: _DevicePanel(saves: s),
        ),
        if (s.conflict != null)
          section(
            'Требует решения',
            '${s.conflicts} '
                '${ruPlural(s.conflicts, 'конфликт', 'конфликта', 'конфликтов')}',
            EvConflictCard(
              conflict: s.conflict!,
              onKeep: (_) => onResolve?.call(),
              onKeepBoth: onResolve,
            ),
          ),
        if (s.cloudReachable)
          section(
            'Лента сохранений',
            'сегодня',
            EvSaveTimeline(points: s.points),
          )
        else
          section(
            'Облако',
            'недоступно',
            EvNothing(
              icon: EvIcons.wifiOff,
              title: 'Хранилище не отвечает',
              detail:
                  '${s.uploadQueue} '
                  '${ruPlural(s.uploadQueue, 'сохранение ждёт', 'сохранения ждут', 'сохранений ждут')}'
                  ' очереди и уйдут в облако автоматически. Играть можно — '
                  'локальные копии в порядке.',
              action: EvMiniButton(
                label: 'Проверить связь',
                icon: EvIcons.retry,
                onPressed: onRetry,
              ),
            ),
          ),
      ],
    );
  }
}

/// Сколько места занято и чем оно наполнено.
class _CloudPanel extends StatelessWidget {
  const _CloudPanel({required this.saves});

  final EvSaves saves;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final s = saves;
    return EvPanel(
      glowCorner: true,
      grouped: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('ОБЛАКО · ЗАНЯТО', style: ev.text.label),
          const SizedBox(height: 8),
          EvBigNumber(
            s.usedGb.toStringAsFixed(1),
            unit: 'ГБ из ${s.quotaGb.toStringAsFixed(0)}',
          ),
          const SizedBox(height: EvSpace.l),
          // Полоса — то же число, что в надписи над ней.
          EvBar(s.fill, cool: true),
          const SizedBox(height: EvSpace.l),
          EvKpiGrid(
            items: [
              ('Игр под защитой', '${s.protected}', c.ink),
              ('Точек отката', '${s.rollbacks}', c.hot2),
              ('Последняя выгрузка', s.lastUpload, c.cool),
              (
                'Конфликтов',
                '${s.conflicts}',
                s.conflicts == 0 ? c.ink : EvColors.warn,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Где лежат копии: этот компьютер, второе устройство, хранилище.
class _DevicePanel extends StatelessWidget {
  const _DevicePanel({required this.saves});

  final EvSaves saves;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return EvPanel(
      grouped: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('УСТРОЙСТВА', style: ev.text.label),
          const SizedBox(height: 14),
          for (final (i, d) in saves.devices.indexed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: i == saves.devices.length - 1
                  ? null
                  : BoxDecoration(
                      border: Border(bottom: BorderSide(color: c.lineSoft)),
                    ),
              child: Row(
                children: [
                  EvIcon(d.icon, size: 18, color: c.ink3),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ev.text.ui(
                            ev.text.title,
                            size: 13.5,
                            weight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          d.detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ev.text.body.copyWith(
                            fontSize: 12,
                            color: c.ink4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  EvDeviceChip(
                    label: d.online
                        ? (d.here ? 'в сети' : 'активно')
                        : 'офлайн',
                    tone: d.online ? EvColors.ok : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
