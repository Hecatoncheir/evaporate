import 'package:flutter/widgets.dart';

import '../art/ev_art.dart';
import '../data/sample_data.dart';
import '../design/theme.dart';
import '../friends/ev_avatar.dart';
import '../friends/friends_data.dart';
import '../widgets/ev_surfaces.dart';

/// Игра в списке «Больше всего часов»: обложка, название, полоса от
/// самой долгой игры и часы.
class EvTopHoursRow extends StatelessWidget {
  const EvTopHoursRow({
    super.key,
    required this.game,
    required this.max,
    this.first = false,
  });

  final SampleGame game;

  /// Часы самой долгой игры списка — её полоса полная.
  final int max;

  /// Первая строка — без линии сверху.
  final bool first;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final hours = game.played.inHours;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: c.lineSoft)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 39,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: c.line),
              color: c.raised,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: EvCover(palette: game.palette, seed: game.seed),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  game.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ev.text.body.copyWith(fontSize: 12.5, color: c.ink),
                ),
                const SizedBox(height: 8),
                EvBar(hours / max),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$hours ч',
            style: ev.text.data.copyWith(fontSize: 12.5, color: c.ink2),
          ),
        ],
      ),
    );
  }
}

/// Друг и сколько вы ему отдали.
class EvGaveRow extends StatelessWidget {
  const EvGaveRow({super.key, required this.person});

  final EvPerson person;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          EvFriendAvatar(initials: person.initials, tint: person.tint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              person.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ev.text.body.copyWith(fontSize: 12.5, color: c.ink),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${person.traffic.fromYouGb} ГБ',
            style: ev.text.data.copyWith(fontSize: 10, color: c.ink4),
          ),
        ],
      ),
    );
  }
}
