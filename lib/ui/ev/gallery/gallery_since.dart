import 'package:flutter/material.dart';

import '../data/game_facts.dart';
import '../data/sample_data.dart';
import '../data/sample_downloads.dart';
import '../data/sample_friends.dart';
import '../design/tokens.dart';
import '../downloads/download_data.dart';
import '../downloads/ev_torrent_row.dart';
import '../downloads/rate_graph.dart';
import '../first_run/ev_first_run_widgets.dart';
import '../friends/ev_avatar.dart';
import '../modes/ev_wall.dart';
import '../overlay/overlay_data.dart';
import '../returning/ev_return_widgets.dart';
import '../returning/return_data.dart';
import '../sound/ev_sound.dart';
import '../sound/voices.dart';
import '../widgets/ev_achievement.dart';
import '../widgets/ev_controls.dart';
import '../widgets/ev_icon.dart';
import '../widgets/ev_surfaces.dart';

/// Всё, что появилось после первой галереи: приборы загрузок, раздача,
/// друзья, достижения, второй запуск, режимы, полоса сценария и голоса.
/// Каждый — на данных окна, а не на своих: галерея показывает то же,
/// что разделы.
class GallerySince extends StatelessWidget {
  const GallerySince({super.key});

  @override
  Widget build(BuildContext context) {
    final downloads = sampleDownloadsFor(EvDownloadsState.active);
    final orbita = downloads.torrents.first;
    final parts = orbita.parts;
    final hero = EvGameFacts.of(sampleHero);
    Widget section(String title, String count, Widget child) => Padding(
      padding: const EdgeInsets.only(top: EvSpace.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EvSectionHeader(title, count: count),
          const SizedBox(height: EvSpace.l),
          child,
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        section(
          'Приборы',
          'приём, рой, кадры',
          EvPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EvBigNumber(
                  (downloads.downKb / 1000).toStringAsFixed(2),
                  unit: 'МБ/с',
                ),
                const SizedBox(height: EvSpace.m),
                EvRateGraph(EvRateSeries(downloads.downKb / 1000).history),
                const SizedBox(height: EvSpace.l),
                Row(
                  children: [
                    EvSwarmRing(
                      received: parts.received / parts.total,
                      inFlight: parts.inFlight / parts.total,
                      verifying: parts.verifying / parts.total,
                    ),
                    const SizedBox(width: EvSpace.l),
                    const Expanded(child: EvPeerHeat(tick: 0, live: false)),
                  ],
                ),
                const SizedBox(height: EvSpace.l),
                EvRateGraph.frames(EvFrameSeries(144).history, height: 56),
              ],
            ),
          ),
        ),
        section('Раздача', 'строка очереди', EvTorrentRow(torrent: orbita)),
        section(
          'Друзья и достижения',
          'шесть оттенков · получено и нет',
          EvPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    for (final p in samplePeople.take(6)) ...[
                      EvFriendAvatar(initials: p.initials, tint: p.tint),
                      const SizedBox(width: EvSpace.s),
                    ],
                  ],
                ),
                const SizedBox(height: EvSpace.l),
                for (final (i, (name, rule))
                    in EvGameFacts.achievements.indexed.take(4))
                  EvAchievementTile(
                    name: name,
                    detail: rule,
                    unlocked: i < hero.unlocked,
                  ),
              ],
            ),
          ),
        ),
        section(
          'Второй запуск',
          'точка сохранения · дайджест',
          Wrap(
            spacing: EvSpace.l,
            runSpacing: EvSpace.l,
            children: [
              SizedBox(
                width: 420,
                child: EvSavePointCard(spot: sampleReturnSpot, onOther: () {}),
              ),
              SizedBox(
                width: EvDigest.width,
                child: EvDigest(
                  events: sampleDigestEvents(),
                  onAction: (_) {},
                  onDone: () {},
                ),
              ),
            ],
          ),
        ),
        section(
          'Режимы',
          'фильтры и плитки «Стены»',
          EvPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EvFilterChip(label: 'Все', selected: true, onTap: () {}),
                const SizedBox(height: EvSpace.m),
                SizedBox(
                  height: 205,
                  child: Row(
                    children: [
                      for (final g in sampleLibrary.skip(1).take(4)) ...[
                        SizedBox(
                          width: 153,
                          child: EvWallTile(game: g, onTap: () {}),
                        ),
                        const SizedBox(width: EvWall.gap),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        section(
          'Сценарий',
          'полоса внизу окна',
          Center(
            child: SizedBox(
              width: EvFlowBar.width,
              child: EvFlowBar(
                index: 3,
                count: 8,
                title: 'Качается',
                detail: '41 % · время — из скорости',
                onPrevious: () {},
                onNext: () {},
                onExit: () {},
              ),
            ),
          ),
        ),
        section(
          'Голоса',
          '${EvVoice.values.length} · ни одного файла',
          const _Voices(),
        ),
      ],
    );
  }
}

/// Голоса: нажатие — послушать. Звучат, только если слой включён
/// в настройках.
class _Voices extends StatelessWidget {
  const _Voices();

  @override
  Widget build(BuildContext context) {
    final sound = EvSoundScope.maybeOf(context);
    return Wrap(
      spacing: EvSpace.s,
      runSpacing: EvSpace.s,
      children: [
        for (final v in EvVoice.values)
          EvMiniButton(
            label: '${v.label} · ${v.length}',
            icon: EvIcons.audio,
            onPressed: sound == null ? null : () => sound.play(v),
          ),
      ],
    );
  }
}
