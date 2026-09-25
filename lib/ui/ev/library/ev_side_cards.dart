import 'package:flutter/widgets.dart';

import '../art/ev_art.dart';
import '../art/key_art.dart';
import '../design/theme.dart';
import '../friends/ev_avatar.dart';
import '../friends/friends_data.dart';
import '../widgets/ev_surfaces.dart';

/// Загрузка в правой колонке.
@immutable
class EvDownloadLine {
  const EvDownloadLine({
    required this.title,
    required this.detail,
    required this.progress,
    required this.palette,
    required this.seed,
    this.checking = false,
  });

  final String title;

  /// «41 % · 592 КБ/с».
  final String detail;

  /// 0…1.
  final double progress;

  final EvCoverPalette palette;
  final int seed;

  /// Идёт проверка частей — полоса циановая, цвета данных.
  final bool checking;
}

/// Карточка правой колонки: панель с подписью капсом.
class _SideCard extends StatelessWidget {
  const _SideCard({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => EvPanel(
    padding: const EdgeInsets.all(15),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label.toUpperCase(), style: context.evt.label),
        const SizedBox(height: 10),
        ...children,
      ],
    ),
  );
}

/// «Друзья · 6 в сети».
class EvFriendsCard extends StatelessWidget {
  const EvFriendsCard({super.key, required this.friends, required this.online});

  final List<EvPerson> friends;
  final int online;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return _SideCard(
      label: 'Друзья · $online в сети',
      children: [
        for (final f in friends)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                EvFriendAvatar(initials: f.initials, tint: f.tint),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ev.text.ui(
                      ev.text.title,
                      weight: FontWeight.w400,
                      size: 12.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  f.shortLine,
                  style: ev.text.data.copyWith(fontSize: 10, color: c.ink4),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// «Качается сейчас»: активные загрузки с полосами и общий приём.
class EvDownloadsNowCard extends StatelessWidget {
  const EvDownloadsNowCard({
    super.key,
    required this.downloads,
    required this.rate,
    required this.slots,
  });

  final List<EvDownloadLine> downloads;

  /// Общий приём: «1.62 МБ/с».
  final String rate;

  /// Сколько загрузок может идти одновременно.
  final int slots;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return _SideCard(
      label: 'Качается сейчас',
      children: [
        for (final (i, d) in downloads.indexed) ...[
          if (i > 0) const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 39,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: c.line),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: EvCover(palette: d.palette, seed: d.seed),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ev.text.ui(
                          ev.text.title,
                          weight: FontWeight.w400,
                          size: 12.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        d.detail,
                        style: ev.text.data.copyWith(
                          fontSize: 10,
                          color: c.ink4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          EvBar(d.progress, cool: d.checking),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'приём $rate',
                style: ev.text.data.copyWith(fontSize: 11, color: c.ink4),
              ),
            ),
            Text(
              '${downloads.length} / $slots',
              style: ev.text.data.copyWith(fontSize: 13, color: c.ink),
            ),
          ],
        ),
      ],
    );
  }
}
