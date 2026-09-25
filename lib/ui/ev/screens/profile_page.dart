import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../data/sample_data.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../library/hero_cta.dart';
import '../library/hero_state.dart';
import '../profile/ev_play_year.dart';
import '../profile/ev_profile_head.dart';
import '../profile/ev_profile_rows.dart';
import '../profile/profile_data.dart';
import '../saves/ev_timeline.dart';
import '../util/plural.dart';
import '../util/units.dart';
import '../widgets/ev_achievement.dart';
import '../widgets/ev_controls.dart';
import '../widgets/ev_icon.dart';
import '../widgets/ev_surfaces.dart';

/// Своя страница. Репутация здесь — рейтинг раздачи, а не «уровень»:
/// поэтому он стоит четвёртой плашкой, подсвечен и повторяется отдельной
/// панелью. Всё, что можно вывести из года игры, библиотеки и друзей,
/// выводится, — плашки и списки под ними не спорят.
class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.profile,
    required this.shares,
    required this.onShare,
  });

  final EvProfile profile;

  /// Что видят друзья — включённые тумблеры.
  final Set<EvShare> shares;

  final void Function(EvShare share, bool on) onShare;

  /// Сколько игр в списке «Больше всего часов».
  static const topCount = 6;

  /// Сколько друзей в «Кому отдали больше всего».
  static const gaveCount = 3;

  @override
  Widget build(BuildContext context) {
    final window = MediaQuery.sizeOf(context);
    final gutter = EvSpace.gutterFor(window);
    final chrome = MediaQuery.paddingOf(context);
    final p = profile;
    final year = p.year;
    final hero = p.library.first;
    return LayoutBuilder(
      builder: (context, box) {
        final content = box.maxWidth - gutter * 2;
        return ListView(
          primary: true,
          padding: EdgeInsets.fromLTRB(
            gutter,
            chrome.top + gutter,
            gutter,
            26 + chrome.bottom,
          ),
          children: [
            EvProfileHead(
              // Кадр — из игры в герое, как `GAMES[0]` в прототипе.
              banner: (
                palette: hero.palette,
                seed: hero.seed + 17,
                sunX: .72,
                sunY: .32,
              ),
              avatar: EvProfileAvatar(initials: p.initials),
              eyebrow: 'В Evaporate ${p.since}',
              name: p.name,
              chips: [
                EvChip('Код: ${p.code}', hot: true, grouped: true),
                EvChip(
                  ruCount(p.people.length, 'друг', 'друга', 'друзей'),
                  grouped: true,
                ),
                EvChip('${p.here.short} · ${p.here.os}', grouped: true),
              ],
              actions: [
                _CopyCode(code: p.code),
                const EvMiniButton(
                  label: 'Изменить',
                  icon: EvIcons.settings,
                  onPressed: null,
                ),
              ],
            ),
            const SizedBox(height: 30),
            EvStatTiles(stats: _stats(p)),
            const SizedBox(height: 30),
            EvSectionHeader(
              'Год игры',
              count:
                  '${ruCount(year.days, 'день', 'дня', 'дней')} · около '
                  '${ruCount(year.hours, 'часа', 'часов', 'часов')}',
            ),
            const SizedBox(height: EvSpace.l),
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
            SizedBox(height: gutter),
            EvHeadPanels(
              left: _TopPanel(games: p.top(topCount)),
              right: _UploadPanel(profile: p),
            ),
            SizedBox(height: gutter),
            EvHeadPanels(
              left: _RecentPanel(
                profile: p,
                // Левая панель равняется по правой, а сетка внутри неё
                // не может спросить свою ширину — считаем её здесь.
                columns: EvAchievementGrid.columnsFor(
                  EvHeadPanels.leftWidth(window, content) - 36,
                ),
              ),
              right: _PrivacyPanel(
                profile: p,
                shares: shares,
                onShare: onShare,
              ),
            ),
          ],
        );
      },
    );
  }

  static List<EvStat> _stats(EvProfile p) => [
    EvStat(
      'Часов в играх',
      formatThousands(p.hours),
      sub:
          '${ruCount(p.year.hours, 'час', 'часа', 'часов')} '
          'за последний год',
    ),
    EvStat(
      'Игр в библиотеке',
      '${p.library.length}',
      sub:
          '${p.installed} '
          '${ruPlural(p.installed, 'установлена', 'установлены', 'установлено')}',
    ),
    EvStat(
      'Достижений',
      '${p.unlocked}',
      tail: '/ ${p.achievements}',
      sub: '${percent(p.unlocked / p.achievements)} % от всех',
    ),
    EvStat(
      'Рейтинг раздачи',
      formatRatio(p.ratio),
      sub: 'отдано ${formatTraffic(p.uploadedGb)}',
      hot: true,
    ),
  ];
}

/// Рейтинг раздачи — два знака после запятой.
String formatRatio(double ratio) =>
    ratio.toStringAsFixed(2).replaceAll('.', ',');

/// «Скопировать код»: на две секунды говорит, что код уже в буфере.
class _CopyCode extends StatefulWidget {
  const _CopyCode({required this.code});

  final String code;

  @override
  State<_CopyCode> createState() => _CopyCodeState();
}

class _CopyCodeState extends State<_CopyCode> {
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.code));
    _reset?.cancel();
    setState(() {
      _reset = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _reset = null);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final copied = _reset != null;
    return EvMiniButton(
      label: copied ? 'Код скопирован' : 'Скопировать код',
      icon: copied ? EvIcons.check : EvIcons.copy,
      onPressed: _copy,
    );
  }
}

/// «Больше всего часов»: игры библиотеки по убыванию часов.
class _TopPanel extends StatelessWidget {
  const _TopPanel({required this.games});

  final List<SampleGame> games;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final max = games.isEmpty ? 1 : games.first.played.inHours;
    return EvPanel(
      grouped: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('БОЛЬШЕ ВСЕГО ЧАСОВ', style: ev.text.label),
          const SizedBox(height: 14),
          for (final (i, g) in games.indexed)
            EvTopHoursRow(game: g, max: max, first: i == 0),
        ],
      ),
    );
  }
}

/// Отдача: сколько вы вернули рою и кому больше всего.
class _UploadPanel extends StatelessWidget {
  const _UploadPanel({required this.profile});

  final EvProfile profile;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final p = profile;
    final uploaded = formatTraffic(p.uploadedGb);
    final space = uploaded.lastIndexOf(' ');
    Widget stat(String icon, String label, String value) => Row(
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
                text: value,
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
          Text('ОТДАЧА', style: ev.text.label),
          const SizedBox(height: 8),
          EvBigNumber(
            uploaded.substring(0, space),
            unit: '${uploaded.substring(space + 1)} отдано',
          ),
          const SizedBox(height: 16),
          EvBar(p.uploadShare, cool: true, height: 4),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              stat(EvIcons.seed, 'отдано', uploaded),
              stat(EvIcons.download, 'получено', formatTraffic(p.receivedGb)),
            ],
          ),
          const SizedBox(height: 14),
          EvCtaNote(
            EvHeroNote(
              'На каждый скачанный гигабайт вы вернули рою '
              '${formatRatio(p.ratio)}',
              icon: EvIcons.peers,
              tone: EvNoteTone.cool,
            ),
          ),
          const SizedBox(height: 20),
          Text('КОМУ ОТДАЛИ БОЛЬШЕ ВСЕГО', style: ev.text.label),
          const SizedBox(height: 8),
          for (final person in p.gaveMost(ProfilePage.gaveCount))
            EvGaveRow(person: person),
        ],
      ),
    );
  }
}

/// Недавние достижения — только те, что карточки игр показывают
/// полученными.
class _RecentPanel extends StatelessWidget {
  const _RecentPanel({required this.profile, required this.columns});

  final EvProfile profile;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    return EvPanel(
      grouped: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('НЕДАВНИЕ ДОСТИЖЕНИЯ', style: ev.text.label),
          const SizedBox(height: 12),
          EvAchievementGrid(
            columns: columns,
            children: [
              for (final e in profile.recent)
                EvAchievementTile(
                  name: e.name,
                  detail: '${e.game.title} · ${e.when}',
                  unlocked: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Что видят друзья и на каких устройствах вы играете.
class _PrivacyPanel extends StatelessWidget {
  const _PrivacyPanel({
    required this.profile,
    required this.shares,
    required this.onShare,
  });

  final EvProfile profile;
  final Set<EvShare> shares;
  final void Function(EvShare share, bool on) onShare;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final devices = profile.devices;
    return EvPanel(
      grouped: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('ЧТО ВИДЯТ ДРУЗЬЯ', style: ev.text.label),
          const SizedBox(height: 6),
          for (final s in EvShare.values)
            EvOption(
              title: s.title,
              description: s.detail,
              last: s == EvShare.values.last,
              control: EvSwitch(
                value: shares.contains(s),
                semanticLabel: s.title,
                onChanged: (on) => onShare(s, on),
              ),
            ),
          const SizedBox(height: 20),
          Text('УСТРОЙСТВА', style: ev.text.label),
          const SizedBox(height: 8),
          for (final (i, (device, hours)) in devices.indexed)
            EvOption(
              leading: EvIcon(device.icon, size: 18, color: c.ink3),
              title: device.short,
              description: [
                if (device.here) 'Этот компьютер' else ?device.os,
                '${formatThousands(hours)} '
                    '${ruPlural(hours, 'час', 'часа', 'часов')}',
                ?device.seen,
              ].join(' · '),
              last: i == devices.length - 1,
              control: device.online
                  ? const EvDeviceChip(label: 'активно', tone: EvColors.ok)
                  : const EvDeviceChip(label: 'офлайн'),
            ),
        ],
      ),
    );
  }
}
