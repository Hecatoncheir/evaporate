import 'package:flutter/widgets.dart';

import '../data/game_facts.dart';
import '../data/sample_data.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../friends/ev_friend_rows.dart';
import '../friends/friends_data.dart';
import '../library/hero_cta.dart';
import '../library/hero_state.dart';
import '../profile/ev_friend_profile_rows.dart';
import '../profile/ev_play_year.dart';
import '../profile/ev_profile_head.dart';
import '../profile/friend_profile_data.dart';
import '../profile/profile_data.dart';
import '../util/plural.dart';
import '../util/units.dart';
import '../widgets/ev_achievement.dart';
import '../widgets/ev_controls.dart';
import '../widgets/ev_icon.dart';
import '../widgets/ev_surfaces.dart';

/// Чужая страница. Полезна сравнением, а не копией своей: первое число —
/// сколько он раздал вам, общие игры — расходящиеся полосы, достижения —
/// только те, которых нет у вас. Скрытое показано скрытым: иначе тумблеры
/// на своей странице ничего бы не значили.
class FriendProfilePage extends StatelessWidget {
  const FriendProfilePage({
    super.key,
    required this.profile,
    required this.library,
    required this.yourGame,
    this.offline = false,
    this.onBack,
    this.onJoin,
    this.onAbout,
    this.onOwnPrivacy,
  });

  final EvFriendProfile profile;

  /// Ваша библиотека — «из 12 в вашей библиотеке».
  final List<SampleGame> library;

  /// Игра в вашем герое: если он в ней же, сессия говорит, что глава та же.
  final SampleGame yourGame;

  /// Сети нет — состояние окна: он не в сети, во что играет — не видно.
  final bool offline;

  final VoidCallback? onBack;
  final ValueChanged<SampleGame>? onJoin;
  final ValueChanged<SampleGame>? onAbout;

  /// «Те же тумблеры есть и у вас» — к своему профилю.
  final VoidCallback? onOwnPrivacy;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final window = MediaQuery.sizeOf(context);
    final gutter = EvSpace.gutterFor(window);
    final chrome = MediaQuery.paddingOf(context);
    final f = profile;
    final p = f.person;
    final playing = !offline && f.playingShown;
    final status = offline ? EvPersonStatus.offline : f.shownStatus;
    final art = playing ? p.game! : library.first;
    final year = f.year;

    Widget section(String title, String? count, Widget child) => Padding(
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
        EvBackLink('Все друзья', onTap: onBack ?? () {}),
        const SizedBox(height: 12),
        EvProfileHead(
          banner: (
            palette: art.palette,
            seed: art.seed + 31,
            sunX: .7,
            sunY: .33,
          ),
          avatar: EvProfileAvatar(
            initials: p.initials,
            tint: p.tint,
            status: evStatusColor(c, status),
          ),
          eyebrow: playing
              ? 'В игре · ${p.game!.title} · ${p.session}'
              : status == EvPersonStatus.offline
              ? p.was ?? 'Не в сети'
              : 'В сети',
          name: p.name,
          chips: [
            EvChip(f.since, hot: true, grouped: true),
            EvChip(
              '${p.common} '
              '${ruPlural(p.common, 'общая игра', 'общие игры', 'общих игр')}',
              grouped: true,
            ),
            EvChip(
              f.shows.contains(EvShare.seeding)
                  ? '${p.past('раздал')} вам ${f.traffic.toYouGb} ГБ'
                  : 'раздача скрыта',
              grouped: true,
            ),
          ],
          actions: const [
            EvMiniButton(
              label: 'Написать',
              icon: EvIcons.note,
              onPressed: null,
            ),
            EvMiniButton(
              label: 'Пригласить',
              icon: EvIcons.play,
              onPressed: null,
            ),
            EvMiniButton(
              label: 'Убрать',
              icon: EvIcons.close,
              danger: true,
              onPressed: null,
            ),
          ],
        ),
        const SizedBox(height: 30),
        EvStatTiles(stats: _stats(f)),
        section(
          'Сейчас играет',
          playing
              ? null
              : f.shows.contains(EvShare.playing)
              ? 'не играет'
              : 'скрыто',
          playing
              ? EvFriendNowCard(
                  game: p.game!,
                  session: p.game == yourGame
                      ? '${p.session} · та же глава, что у вас'
                      : p.session!,
                  onJoin: onJoin == null ? null : () => onJoin!(p.game!),
                  onAbout: onAbout == null ? null : () => onAbout!(p.game!),
                )
              : _NotPlaying(profile: f, status: status),
        ),
        SizedBox(height: gutter),
        EvHeadPanels(
          left: _CommonPanel(profile: f),
          right: _TrafficPanel(profile: f, onOwnPrivacy: onOwnPrivacy),
        ),
        if (year != null)
          section(
            'Год игры',
            '${ruCount(year.days, 'день', 'дня', 'дней')} · около '
                '${ruCount(year.hours, 'часа', 'часов', 'часов')}',
            EvPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EvPlayYearMap(year: year),
                  const SizedBox(height: 14),
                  EvPlayYearLegend(year: year),
                ],
              ),
            ),
          ),
        if (f.only.isNotEmpty)
          section(
            'Достижения, которых нет у вас',
            '${f.only.length}',
            EvPanel(
              child: EvAchievementGrid(
                children: [
                  for (final (game, index) in f.only)
                    EvAchievementTile(
                      name: EvGameFacts.achievements[index].$1,
                      detail:
                          '${game.title} · '
                          '${EvGameFacts.achievements[index].$2}',
                      unlocked: true,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<EvStat> _stats(EvFriendProfile f) {
    final p = f.person;
    final ach = f.achievements;
    return [
      // Первое число — не его часы, а сколько он раздал вам: для
      // торрент-лаунчера это и есть отношения между двумя людьми.
      EvStat(
        '${p.past('Раздал')} вам',
        '${f.traffic.toYouGb} ГБ',
        sub: 'вы ${p.him} — ${f.traffic.fromYouGb} ГБ',
        hot: true,
      ),
      if (f.hours case final hours?)
        EvStat('Часов в играх', formatThousands(hours), sub: 'за всё время')
      else
        EvStat.hidden('Часов в играх', sub: '${p.he} не показывает часы'),
      EvStat(
        'Общих игр',
        '${p.common}',
        sub: 'из ${library.length} в вашей библиотеке',
      ),
      if (ach case (final got, final all))
        EvStat(
          'Достижений',
          '$got',
          tail: '/ $all',
          sub: '${percent(got / all)} % от всех',
        )
      else
        EvStat.hidden('Достижений', sub: '${p.he} не показывает достижения'),
    ];
  }
}

/// Вместо карточки «сейчас играет»: скрыл он игру или просто не играет.
/// Это разные вещи, и говорить их нужно разными словами.
class _NotPlaying extends StatelessWidget {
  const _NotPlaying({required this.profile, required this.status});

  final EvFriendProfile profile;
  final EvPersonStatus status;

  @override
  Widget build(BuildContext context) {
    final p = profile.person;
    if (!profile.shows.contains(EvShare.playing)) {
      return EvHiddenBox(
        icon: EvIcons.lock,
        title: '${p.firstName} не показывает, во что играет',
        detail:
            'Это выключается одним тумблером в своём профиле. Вы увидите '
            '${p.female ? 'её' : 'его'} в сети, но не увидите игру.',
      );
    }
    return switch (status) {
      EvPersonStatus.offline => EvHiddenBox(
        icon: EvIcons.friends,
        title: '${p.firstName} не в сети',
        detail:
            '${_capital(p.was ?? 'давно не заходил')}. Когда '
            '${p.he} запустит игру, она появится здесь.',
      ),
      _ => EvHiddenBox(
        icon: EvIcons.friends,
        title: '${p.firstName} в сети, но не в игре',
        detail: 'Когда ${p.he} запустит игру, она появится здесь.',
      ),
    };
  }

  static String _capital(String s) => s[0].toUpperCase() + s.substring(1);
}

/// Общие игры — расходящиеся полосы, самые долгие сверху.
class _CommonPanel extends StatelessWidget {
  const _CommonPanel({required this.profile});

  final EvFriendProfile profile;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final p = profile.person;
    int longest(EvCommonGame g) =>
        g.his == null || g.mine > g.his! ? g.mine : g.his!;
    final games = profile.common.toList()
      ..sort((a, b) => longest(b).compareTo(longest(a)));
    return EvPanel(
      grouped: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('ОБЩИЕ ИГРЫ', style: ev.text.label)),
              // Показаны не все общие — плашка сверху говорит, сколько
              // их всего, и список не должен с ней спорить.
              Text(
                '${games.length} из ${p.common}',
                style: ev.text.data.copyWith(fontSize: 10, color: c.ink4),
              ),
            ],
          ),
          const SizedBox(height: 12),
          EvCommonLegend(who: p.firstName.toLowerCase()),
          const SizedBox(height: 6),
          for (final (i, g) in games.indexed)
            EvCommonGameRow(common: g, first: i == 0),
        ],
      ),
    );
  }
}

/// Раздача между вами в обе стороны и что он скрыл.
class _TrafficPanel extends StatelessWidget {
  const _TrafficPanel({required this.profile, this.onOwnPrivacy});

  final EvFriendProfile profile;
  final VoidCallback? onOwnPrivacy;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final f = profile;
    final p = f.person;
    final t = f.traffic;
    final share = percent(t.share);
    final hidden = f.hidden;
    Widget stat(String icon, String label, int gb) => Row(
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
                text: '$gb ГБ',
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
      glowCorner: true,
      grouped: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('РАЗДАЧА МЕЖДУ ВАМИ', style: ev.text.label),
          const SizedBox(height: 8),
          EvBigNumber('${t.toYouGb}', unit: 'ГБ вам'),
          const SizedBox(height: 16),
          EvBar(t.share, cool: true, height: 4),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              stat(EvIcons.seed, '${p.he} вам', t.toYouGb),
              stat(EvIcons.download, 'вы ${p.him}', t.fromYouGb),
            ],
          ),
          const SizedBox(height: 14),
          EvCtaNote(
            EvHeroNote(
              share >= 50
                  ? '$share % трафика между вами шло от ${p.fromHim} — '
                        '${p.he} раздаёт вам чаще, чем вы ${p.him}'
                  : 'Только $share % шло от ${p.fromHim}: вы раздаёте '
                        '${p.him} заметно больше',
              icon: EvIcons.peers,
              tone: EvNoteTone.cool,
            ),
          ),
          const SizedBox(height: 20),
          Text('ЧТО СКРЫТО', style: ev.text.label),
          const SizedBox(height: 10),
          if (hidden.isEmpty)
            EvHiddenBox(
              icon: EvIcons.check,
              title: 'Ничего не скрыто',
              detail:
                  '${p.firstName} показывает друзьям всё: игру, часы, '
                  'достижения и раздачу.',
            )
          else ...[
            for (final (i, (label, icon)) in hidden.indexed)
              EvHiddenRow(icon: icon, label: label, first: i == 0),
            const SizedBox(height: 12),
            EvHiddenBox(
              icon: EvIcons.info,
              title: 'Это ${p.his} выбор, а не ошибка',
              detail:
                  'Те же четыре тумблера есть и у вас — в своём профиле, '
                  'раздел «Что видят друзья».',
              action: onOwnPrivacy == null
                  ? null
                  : EvMiniButton(
                      label: 'Мой профиль',
                      icon: EvIcons.go,
                      onPressed: onOwnPrivacy,
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
