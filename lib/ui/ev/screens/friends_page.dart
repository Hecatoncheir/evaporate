import 'package:flutter/widgets.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../friends/ev_friend_rows.dart';
import '../friends/friends_data.dart';
import '../widgets/ev_thread.dart';
import '../util/plural.dart';
import '../widgets/ev_icon.dart';
import '../widgets/ev_surfaces.dart';

/// Друзья — не список контактов, а вторая сеть раздачи.
///
/// Поэтому первое число раздела — сколько они дают вам прямо сейчас,
/// а главный блок — «Раздают вам»: он объясняет, почему приём такой,
/// какой есть. Кто в сети и лента — ниже.
class FriendsPage extends StatelessWidget {
  const FriendsPage({
    super.key,
    required this.friends,
    required this.rateKb,
    this.onInvite,
    this.onDownloads,
    this.onPerson,
  });

  final EvFriends friends;

  /// Весь приём окна, КБ/с, — из него считается доля друзей.
  final int rateKb;

  /// Заявка принята или отклонена.
  final VoidCallback? onInvite;

  /// «К загрузкам».
  final VoidCallback? onDownloads;

  final ValueChanged<EvPerson>? onPerson;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final window = MediaQuery.sizeOf(context);
    final gutter = EvSpace.gutterFor(window);
    final chrome = MediaQuery.paddingOf(context);
    final f = friends;

    Widget section(
      String title,
      String count,
      Widget child, {
      Widget? trailing,
    }) => Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EvSectionHeader(title, count: count, trailing: trailing),
          const SizedBox(height: EvSpace.l),
          child,
        ],
      ),
    );

    final playing = f.playing;
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
          left: _FromFriendsPanel(friends: f, rateKb: rateKb),
          right: _SharedPanel(friends: f, onInvite: onInvite),
        ),
        section(
          'Сейчас в игре',
          playing.isEmpty
              ? 'никого'
              : '${playing.length} из ${f.people.length}',
          playing.isEmpty
              ? EvNothing(
                  icon: f.offline ? EvIcons.wifiOff : EvIcons.friends,
                  title: f.offline
                      ? 'Нет связи с друзьями'
                      : 'Сейчас никто не играет',
                  detail: f.offline
                      ? 'Список и раздача от друзей вернутся, как только '
                            'появится сеть'
                      : 'Мы покажем здесь, когда кто-нибудь запустит игру',
                )
              : _NowPlayingGrid(people: playing, onPerson: onPerson),
        ),
        section(
          'Раздают вам',
          f.seeders.isEmpty
              ? 'никто'
              : '${f.seeders.length} '
                    '${ruPlural(f.seeders.length, 'источник', 'источника', 'источников')}',
          f.seeders.isEmpty
              ? const EvNothing(
                  icon: EvIcons.wifiOff,
                  title: 'Пиры от друзей недоступны',
                  detail:
                      'Загрузки идут только из общего роя, скорость просядет',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, s) in f.seeders.indexed) ...[
                      if (i > 0) const SizedBox(height: 10),
                      EvSeederRow(
                        seeder: s,
                        onOpen: onPerson == null
                            ? null
                            : () => onPerson!(s.person),
                      ),
                    ],
                  ],
                ),
          trailing: f.seeders.isEmpty
              ? null
              : _Link('К загрузкам', onTap: onDownloads),
        ),
        section(
          'Все друзья',
          '${f.online} в сети из ${f.people.length}',
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: ev.radii.b3,
              border: Border.all(color: c.lineSoft),
            ),
            child: ClipRRect(
              borderRadius: ev.radii.b3,
              child: Column(
                children: [
                  for (final (i, p) in f.people.indexed)
                    EvFriendRow(
                      person: p,
                      offline: f.offline,
                      last: i == f.people.length - 1,
                      onOpen: onPerson == null ? null : () => onPerson!(p),
                    ),
                ],
              ),
            ),
          ),
          trailing: _Link('Добавить по коду', onTap: onInvite),
        ),
        section('Лента', 'за неделю', _Feed(entries: f.feed)),
      ],
    );
  }
}

/// Ссылка в заголовке раздела.
class _Link extends StatefulWidget {
  const _Link(this.label, {this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  State<_Link> createState() => _LinkState();
}

class _LinkState extends State<_Link> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Text(
          widget.label,
          style: ev.text.body.copyWith(
            fontSize: 12,
            color: _hover ? c.hot2 : c.ink3,
          ),
        ),
      ),
    );
  }
}

/// Сколько друзья дают прямо сейчас — и какая это доля приёма.
class _FromFriendsPanel extends StatelessWidget {
  const _FromFriendsPanel({required this.friends, required this.rateKb});

  final EvFriends friends;
  final int rateKb;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final f = friends;
    final share = (f.shareOf(rateKb) * 100).round();
    return EvPanel(
      glowCorner: true,
      grouped: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('ОТ ДРУЗЕЙ · ПРЯМО СЕЙЧАС', style: ev.text.label),
          const SizedBox(height: 8),
          EvBigNumber(
            (f.fromFriendsKb / 1000).toStringAsFixed(2),
            unit: 'МБ/с',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              EvIcon(EvIcons.peers, size: 14, color: c.cool),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  f.seeders.isEmpty
                      ? 'Нет сети — весь приём идёт из общего роя'
                      : '$share % вашей скорости приёма дают друзья, а не рой',
                  style: ev.text.data.copyWith(fontSize: 11, color: c.cool),
                ),
              ),
            ],
          ),
          const SizedBox(height: EvSpace.l),
          EvKpiGrid(
            items: [
              ('В сети', '${f.online}', EvColors.ok),
              ('Всего', '${f.people.length}', c.ink),
              ('Раздают вам', '${f.seeders.length}', c.cool),
              ('Отдано друзьям', '${f.givenGb} ГБ', c.hot2),
            ],
          ),
        ],
      ),
    );
  }
}

/// Заявка и то, насколько ваша библиотека совпадает с их библиотеками.
class _SharedPanel extends StatelessWidget {
  const _SharedPanel({required this.friends, this.onInvite});

  final EvFriends friends;
  final VoidCallback? onInvite;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final lib = friends.library;
    Widget stat(String icon, String label, int value) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(opacity: .8, child: EvIcon(icon, size: 13, color: c.ink3)),
        const SizedBox(width: 7),
        Text.rich(
          TextSpan(
            style: ev.text.data.copyWith(fontSize: 11.5),
            children: [
              TextSpan(text: '$label '),
              TextSpan(
                text: '$value',
                style: ev.text.mono(
                  ev.text.data,
                  size: 11.5,
                  weight: FontWeight.w500,
                  color: c.ink2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return EvPanel(
      grouped: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('ЗАЯВКА В ДРУЗЬЯ', style: ev.text.label),
          const SizedBox(height: 12),
          if (friends.invite != null)
            EvInviteCard(
              invite: friends.invite!,
              onAccept: onInvite,
              onDecline: onInvite,
            )
          else
            Row(
              children: [
                EvIcon(EvIcons.check, size: 14, color: c.ink3),
                const SizedBox(width: 9),
                Text(
                  'Новых заявок нет',
                  style: ev.text.data.copyWith(fontSize: 11),
                ),
              ],
            ),
          const SizedBox(height: 20),
          Text('ОБЩАЯ БИБЛИОТЕКА', style: ev.text.label),
          const SizedBox(height: 10),
          Row(
            children: [
              EvIcon(EvIcons.library, size: 14, color: c.ink3),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'У вас ${lib.shared} '
                  '${ruPlural(lib.shared, 'игра', 'игры', 'игр')}, '
                  '${ruPlural(lib.shared, 'которая есть', 'которые есть', 'которые есть')} '
                  'хотя бы у одного друга',
                  style: ev.text.data.copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          EvStackBar(
            parts: [
              (lib.everyone, c.hot1),
              (lib.half, c.cool),
              (lib.onlyYou, c.arc),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              stat(EvIcons.seed, 'у всех', lib.everyone),
              stat(EvIcons.peers, 'у половины', lib.half),
              stat(EvIcons.disk, 'только у вас', lib.onlyYou),
            ],
          ),
        ],
      ),
    );
  }
}

/// Полка карточек «сейчас в игре»: как в прототипе — сетка от 272 px.
class _NowPlayingGrid extends StatelessWidget {
  const _NowPlayingGrid({required this.people, this.onPerson});

  final List<EvPerson> people;
  final ValueChanged<EvPerson>? onPerson;

  static const minWidth = 272.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final columns = ((box.maxWidth + 14) / (minWidth + 14)).floor().clamp(
        1,
        people.length,
      );
      final width = (box.maxWidth - (columns - 1) * 14) / columns;
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          for (final p in people)
            SizedBox(
              width: width,
              child: EvNowPlayingCard(
                person: p,
                onOpen: onPerson == null ? null : () => onPerson!(p),
              ),
            ),
        ],
      );
    },
  );
}

/// Лента друзей: та же нить, что в сохранениях, — события в системе
/// выглядят одинаково, где бы они ни были.
class _Feed extends StatelessWidget {
  const _Feed({required this.entries});

  final List<EvFeedEntry> entries;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return EvThread(
      children: [
        for (final (i, e) in entries.indexed)
          EvThreadRow(
            now: i == 0,
            // Строка ленты ниже, чем в сохранениях: точка садится выше.
            dotTop: 17,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      style: ev.text.body.copyWith(
                        fontSize: 13,
                        height: 1.45,
                        color: c.ink2,
                      ),
                      children: [
                        TextSpan(
                          text: e.person.name,
                          style: ev.text.ui(
                            ev.text.title,
                            size: 13,
                            color: c.ink,
                          ),
                        ),
                        TextSpan(text: ' ${e.did} '),
                        TextSpan(
                          text: e.what,
                          style: e.bright
                              ? ev.text.body.copyWith(
                                  fontSize: 13,
                                  color: c.hot2,
                                )
                              : ev.text.ui(
                                  ev.text.title,
                                  size: 13,
                                  color: c.ink,
                                ),
                        ),
                        TextSpan(text: e.tail),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    e.when,
                    style: ev.text.data.copyWith(fontSize: 10, color: c.ink4),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
