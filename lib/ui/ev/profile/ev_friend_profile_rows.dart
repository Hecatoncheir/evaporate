import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../art/ev_art.dart';
import '../data/sample_data.dart';
import '../design/effects.dart';
import '../design/theme.dart';
import '../widgets/ev_controls.dart';
import '../widgets/ev_focusable.dart';
import '../widgets/ev_icon.dart';
import '../widgets/ev_play_button.dart';
import '../widgets/ev_surfaces.dart';
import 'friend_profile_data.dart';

/// «Все друзья»: назад к списку, над шапкой чужой страницы.
class EvBackLink extends StatefulWidget {
  const EvBackLink(this.label, {super.key, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<EvBackLink> createState() => _EvBackLinkState();
}

class _EvBackLinkState extends State<EvBackLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final color = _hover ? c.hot2 : c.ink4;
    return Align(
      alignment: Alignment.centerLeft,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: EvFocusable(
          onActivate: widget.onTap,
          radius: ev.radii.r1,
          child: Semantics(
            button: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.rotate(
                  angle: math.pi,
                  child: EvIcon(EvIcons.go, size: 13, color: color),
                ),
                const SizedBox(width: 9),
                Text(
                  widget.label.toUpperCase(),
                  style: ev.text.data.copyWith(
                    fontSize: 10.5,
                    letterSpacing: 1.05,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Подписи к полосам общих игр: вы — янтарём, он — цианом.
class EvCommonLegend extends StatelessWidget {
  const EvCommonLegend({super.key, required this.who});

  /// Его имя строчными: «антон».
  final String who;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final style = ev.text.data.copyWith(fontSize: 10, color: c.ink4);
    Widget key(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 7),
        Text(label, style: style),
      ],
    );
    return Row(
      children: [
        key(c.hot2, 'вы'),
        const SizedBox(width: 16),
        key(c.cool, who),
      ],
    );
  }
}

/// Общая игра: ваши часы влево янтарём, его — вправо цианом от общей
/// середины. Длиннее та полоса, кто в игре дольше; скрытые часы так и
/// подписаны «скрыто».
class EvCommonGameRow extends StatelessWidget {
  const EvCommonGameRow({super.key, required this.common, this.first = false});

  final EvCommonGame common;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final g = common.game;
    final his = common.his;
    final max = math.max(1, math.max(common.mine, his ?? 0));
    TextStyle hours(Color color) => ev.text.mono(
      ev.text.data,
      size: 10.5,
      weight: FontWeight.w500,
      color: color,
    );
    Widget bar(double value, List<Color> colors, Color glow, Alignment side) =>
        Flexible(
          child: FractionallySizedBox(
            widthFactor: value,
            alignment: side,
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                borderRadius: ev.radii.bPill,
                gradient: LinearGradient(colors: colors),
                boxShadow: [
                  BoxShadow(color: glow.withValues(alpha: .4), blurRadius: 10),
                ],
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
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
              child: EvCover(palette: g.palette, seed: g.seed),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  g.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ev.text.body.copyWith(fontSize: 12.5, color: c.ink),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 16,
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('${common.mine} ч', style: hours(c.hot2)),
                            const SizedBox(width: 8),
                            bar(
                              common.mine / max,
                              [c.hotDeep, c.hot2],
                              c.hot1,
                              Alignment.centerRight,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(width: 1, height: 14, color: c.line),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: his == null
                              ? [Text('скрыто', style: hours(c.ink4))]
                              : [
                                  bar(
                                    his / max,
                                    [const Color(0xFF1B6F8A), c.cool],
                                    c.cool,
                                    Alignment.centerLeft,
                                  ),
                                  const SizedBox(width: 8),
                                  Text('$his ч', style: hours(c.cool)),
                                ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Пунктирная плашка: то, чего здесь нет, и почему. Пунктир — как
/// у пустого раздела: место есть, содержимого нет.
class EvHiddenBox extends StatelessWidget {
  const EvHiddenBox({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    this.action,
  });

  final String icon;
  final String title;
  final String detail;

  /// Ссылка под текстом: «к своим настройкам».
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return CustomPaint(
      painter: EvDashedBorder(color: c.line, radius: ev.radii.r3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: EvIcon(icon, size: 17, color: c.ink4),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: ev.text.body.copyWith(fontSize: 13, color: c.ink2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: ev.text.body.copyWith(
                      fontSize: 12,
                      height: 1.5,
                      color: c.ink4,
                    ),
                  ),
                  if (action != null) ...[const SizedBox(height: 8), action!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Строка «Что скрыто»: что именно и пометка справа.
class EvHiddenRow extends StatelessWidget {
  const EvHiddenRow({
    super.key,
    required this.icon,
    required this.label,
    this.first = false,
  });

  final String icon;
  final String label;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: c.lineSoft)),
      ),
      child: Row(
        children: [
          EvIcon(icon, size: 14, color: c.ink4),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: ev.text.body.copyWith(fontSize: 12.5, color: c.ink3),
            ),
          ),
          Text(
            'скрыто',
            style: ev.text.data.copyWith(fontSize: 10, color: c.ink4),
          ),
        ],
      ),
    );
  }
}

/// Во что друг играет прямо сейчас: кадр игры, название, сессия и два
/// действия — присоединиться и открыть карточку игры.
class EvFriendNowCard extends StatelessWidget {
  const EvFriendNowCard({
    super.key,
    required this.game,
    required this.session,
    this.onJoin,
    this.onAbout,
  });

  final SampleGame game;

  /// «2 ч 14 мин · Глава 5 · та же глава, что у вас».
  final String session;

  final VoidCallback? onJoin;
  final VoidCallback? onAbout;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final window = MediaQuery.sizeOf(context).width;
    return ClipRRect(
      borderRadius: ev.radii.b4,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: ev.radii.b4,
          border: Border.all(color: c.line),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: EvCover(palette: game.palette, seed: game.seed),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color.fromRGBO(6, 6, 10, .94),
                      Color.fromRGBO(6, 6, 10, .4),
                      Color.fromRGBO(6, 6, 10, 0),
                    ],
                    stops: [.1, .52, 1],
                  ),
                ),
              ),
            ),
            Container(
              constraints: const BoxConstraints(minHeight: 150),
              alignment: Alignment.bottomLeft,
              padding: EdgeInsets.all((window * .02).clamp(15.0, 20.0)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          game.title,
                          style: ev.text.dsp(
                            ev.text.display((window * .02).clamp(16.0, 22.0)),
                            weight: FontWeight.w600,
                            letterSpacing: -.2,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          session,
                          style: ev.text.data.copyWith(
                            fontSize: 11,
                            color: c.ink3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  EvPlayButton(
                    label: 'Присоединиться',
                    requireHold:
                        EvEffectsScope.maybeOf(context)?.holdToPlay ?? true,
                    height: 42,
                    onLaunch: onJoin,
                  ),
                  const SizedBox(width: 9),
                  EvGhostButton(
                    label: 'Об игре',
                    icon: EvIcons.info,
                    height: 42,
                    onPressed: onAbout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
