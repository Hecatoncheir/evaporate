import 'package:flutter/widgets.dart';

import '../art/ev_art.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../util/plural.dart';
import '../util/units.dart';
import '../widgets/ev_controls.dart';
import '../widgets/ev_focusable.dart';
import '../widgets/ev_icon.dart';
import '../widgets/ev_surfaces.dart';
import 'ev_avatar.dart';
import 'friends_data.dart';

/// Цвет точки состояния на аватаре: горячая — в игре, зелёная — в сети,
/// серая — не в сети. Тот же цвет получает строка состояния.
Color evStatusColor(EvColors c, EvPersonStatus status) => switch (status) {
  EvPersonStatus.playing => c.hot2,
  EvPersonStatus.online => EvColors.ok,
  EvPersonStatus.offline => c.ink4,
};

/// «Сейчас в игре»: карточка на обложке той игры, в которую играет друг.
/// Кадр здесь — не украшение: по нему игру узнают раньше, чем прочитают
/// название.
class EvNowPlayingCard extends StatefulWidget {
  const EvNowPlayingCard({super.key, required this.person, this.onOpen});

  final EvPerson person;
  final VoidCallback? onOpen;

  @override
  State<EvNowPlayingCard> createState() => _EvNowPlayingCardState();
}

class _EvNowPlayingCardState extends State<EvNowPlayingCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final p = widget.person;
    final game = p.game!;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: EvFocusable(
        onActivate: widget.onOpen,
        radius: ev.radii.r4,
        child: Semantics(
          button: true,
          label: '${p.name} · ${game.title}',
          child: AnimatedContainer(
            duration: EvMotion.hover,
            curve: EvMotion.easeOut,
            transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
            constraints: const BoxConstraints(minHeight: 170),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: ev.radii.b4,
              border: Border.all(
                color: _hover ? c.hot1.withValues(alpha: .45) : c.line,
              ),
              boxShadow: _hover
                  ? [
                      BoxShadow(
                        color: const Color(0xFF000000).withValues(alpha: .6),
                        blurRadius: 44,
                        offset: const Offset(0, 20),
                      ),
                      BoxShadow(
                        color: c.hot1.withValues(alpha: .2),
                        blurRadius: 34,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                Positioned.fill(
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 600),
                    curve: EvMotion.easeOut,
                    scale: _hover ? 1.11 : 1.05,
                    child: EvCover(palette: game.palette, seed: game.seed),
                  ),
                ),
                // Кадр уходит в землю снизу — иначе текст ляжет на него.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          c.ground.withValues(alpha: .96),
                          c.ground.withValues(alpha: .62),
                          c.ground.withValues(alpha: .18),
                        ],
                        stops: const [.08, .48, 1],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          EvFriendAvatar(
                            initials: p.initials,
                            tint: p.tint,
                            size: 34,
                            status: EvColors.ok,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: ev.text.ui(ev.text.title, size: 14),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'в игре',
                                  style: ev.text.data.copyWith(
                                    fontSize: 10,
                                    color: EvColors.ok,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 11),
                      Text(
                        game.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ev.text
                            .dsp(ev.text.display(14), weight: FontWeight.w600)
                            .copyWith(height: 1.2),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        p.session ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ev.text.data.copyWith(fontSize: 10.5),
                      ),
                      const SizedBox(height: 12),
                      // На узкой карточке кнопки переносятся, а не
                      // срезаются: «Написать» — тоже действие.
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          EvMiniButton(
                            label: 'Присоединиться',
                            icon: EvIcons.play,
                            onPressed: widget.onOpen,
                          ),
                          EvMiniButton(
                            label: 'Написать',
                            icon: EvIcons.note,
                            onPressed: widget.onOpen,
                          ),
                        ],
                      ),
                    ],
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

/// «Раздают вам»: кто, что и какую долю этой раздачи он держит.
/// Полоса — доля из приёма именно этой раздачи, а не из всего приёма.
class EvSeederRow extends StatelessWidget {
  const EvSeederRow({super.key, required this.seeder, this.onOpen});

  final EvSeeder seeder;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final s = seeder;
    final share = (s.share * 100).round();
    return EvFocusable(
      onActivate: onOpen,
      radius: ev.radii.r3,
      child: Semantics(
        button: onOpen != null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: ev.radii.b3,
            border: Border.all(color: c.lineSoft),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                c.ink.withValues(alpha: .028),
                c.ink.withValues(alpha: .005),
              ],
            ),
          ),
          child: Row(
            children: [
              EvFriendAvatar(
                initials: s.person.initials,
                tint: s.person.tint,
                size: 32,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 9,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          s.person.name,
                          style: ev.text.ui(ev.text.title, size: 13.5),
                        ),
                        Text.rich(
                          TextSpan(
                            style: ev.text.data.copyWith(
                              fontSize: 10.5,
                              color: c.ink4,
                            ),
                            children: [
                              const TextSpan(text: 'раздаёт '),
                              TextSpan(
                                text: s.game.title,
                                style: ev.text.mono(
                                  ev.text.data,
                                  size: 10.5,
                                  weight: FontWeight.w500,
                                  color: c.cool,
                                ),
                              ),
                              TextSpan(
                                text: ' · $share % из ${formatRate(s.ofKb)}',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    EvBar(s.share, cool: true),
                  ],
                ),
              ),
              const SizedBox(width: 13),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatRate(s.rateKb),
                    style: ev.text.mono(ev.text.data, size: 15, color: c.cool),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'от ${seeder.person.fromHim}',
                    style: ev.text.data.copyWith(fontSize: 9.5, color: c.ink4),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Строка списка «Все друзья».
class EvFriendRow extends StatefulWidget {
  const EvFriendRow({
    super.key,
    required this.person,
    required this.last,
    this.offline = false,
    this.onOpen,
    this.onWrite,
  });

  final EvPerson person;
  final bool last;

  /// Сети нет — все показаны не в сети.
  final bool offline;

  /// Клик по строке — страница друга.
  final VoidCallback? onOpen;

  final VoidCallback? onWrite;

  /// Ниже 820 «общих» и «написать» уходят: имя важнее.
  static const wide = 820.0;

  @override
  State<EvFriendRow> createState() => _EvFriendRowState();
}

class _EvFriendRowState extends State<EvFriendRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final p = widget.person;
    final status = widget.offline ? EvPersonStatus.offline : p.status;
    final wide = MediaQuery.sizeOf(context).width >= EvFriendRow.wide;
    final color = evStatusColor(c, status);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: EvFocusable(
        onActivate: widget.onOpen,
        radius: 0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: BoxDecoration(
            color: _hover ? c.ink.withValues(alpha: .03) : null,
            border: widget.last
                ? null
                : Border(bottom: BorderSide(color: c.lineSoft)),
          ),
          child: Row(
            children: [
              EvFriendAvatar(
                initials: p.initials,
                tint: p.tint,
                size: 32,
                status: color,
              ),
              const SizedBox(width: 13),
              Expanded(
                flex: 14,
                child: Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ev.text.ui(
                    ev.text.title,
                    size: 13.5,
                    weight: FontWeight.w400,
                    color: status == EvPersonStatus.offline ? c.ink3 : c.ink,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                flex: 10,
                child: Text(
                  p.lineFor(status),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ev.text.data.copyWith(
                    fontSize: 10.5,
                    color: status == EvPersonStatus.offline ? c.ink4 : color,
                  ),
                ),
              ),
              if (wide) ...[
                const SizedBox(width: 13),
                SizedBox(
                  width: 86,
                  child: Text(
                    '${p.common} '
                    '${ruPlural(p.common, 'общая', 'общие', 'общих')}',
                    textAlign: TextAlign.right,
                    style: ev.text.data.copyWith(fontSize: 10.5),
                  ),
                ),
                const SizedBox(width: 13),
                // Кнопка появляется под курсором, но место под неё занято
                // всегда — иначе строка дёргалась бы при наведении.
                Opacity(
                  opacity: _hover ? 1 : 0,
                  child: EvMiniButton(
                    label: 'Написать',
                    icon: EvIcons.note,
                    onPressed: _hover ? widget.onWrite : null,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Заявка в друзья: кто и почему — и два решения рядом.
class EvInviteCard extends StatelessWidget {
  const EvInviteCard({
    super.key,
    required this.invite,
    this.onAccept,
    this.onDecline,
  });

  final EvInvite invite;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        borderRadius: ev.radii.b3,
        border: Border.all(color: c.hot1.withValues(alpha: .34)),
        color: c.hot1.withValues(alpha: .06),
      ),
      child: Wrap(
        spacing: 13,
        runSpacing: 13,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              EvFriendAvatar(
                initials: invite.initials,
                tint: invite.tint,
                size: 34,
              ),
              const SizedBox(width: 13),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      invite.name,
                      style: ev.text.ui(ev.text.title, size: 13.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      invite.detail,
                      style: ev.text.data.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              EvGhostButton(
                label: 'Принять',
                icon: EvIcons.check,
                height: 38,
                grouped: true,
                onPressed: onAccept,
              ),
              const SizedBox(width: 8),
              EvMiniButton(
                label: 'Отклонить',
                icon: EvIcons.close,
                danger: true,
                onPressed: onDecline,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Полоса из нескольких долей подряд. Доли считаются из тех же чисел,
/// что написаны под ней, поэтому третьей правды между ними нет.
class EvStackBar extends StatelessWidget {
  const EvStackBar({super.key, required this.parts, this.height = 8});

  /// Пары «сколько» и «каким цветом».
  final List<(int, Color)> parts;

  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.ev.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Row(
          // Доли — пустые коробки без своего размера: без stretch
          // они получили бы нулевую высоту и полосы не было бы видно.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, part) in parts.indexed)
              Expanded(
                flex: part.$1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: part.$2,
                    // Между долями — тёмный шов, как в прототипе.
                    border: i == 0
                        ? null
                        : Border(
                            left: BorderSide(
                              color: c.ground.withValues(alpha: .6),
                            ),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
