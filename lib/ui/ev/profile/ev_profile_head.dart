import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../art/ev_art.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../friends/ev_avatar.dart';
import '../widgets/ev_icon.dart';
import '../widgets/ev_surfaces.dart';

/// Шапка страницы игрока: широкий кадр, аватар, надглавие, имя в две
/// строки, чипы и действия справа. Та же шапка встанет на страницу
/// друга — с его аватаром и его кадром.
class EvProfileHead extends StatelessWidget {
  const EvProfileHead({
    super.key,
    required this.banner,
    required this.avatar,
    required this.eyebrow,
    required this.name,
    required this.chips,
    this.actions = const [],
  });

  final EvBanner banner;
  final Widget avatar;
  final String eyebrow;

  /// «Виталий В.»: последнее слово — ударная строка.
  final String name;

  final List<Widget> chips;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final window = MediaQuery.sizeOf(context).width;
    // clamp(20px, 3vw, 32px) и clamp(16px, 2.4vw, 26px) из прототипа.
    final pad = (window * .03).clamp(20.0, 32.0);
    final gap = (window * .024).clamp(16.0, 26.0);
    final size = (window * .04).clamp(28.0, 50.0);
    final words = name.split(' ');
    final title = ev.text.display(size);
    return ClipRRect(
      borderRadius: ev.radii.b5,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: ev.radii.b5,
          border: Border.all(color: c.line),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: EvBannerArt(banner)),
            // Слева — почти сплошной фон под текстом, справа кадр виден.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      c.sub,
                      const Color.fromRGBO(10, 11, 17, .86),
                      const Color.fromRGBO(10, 11, 17, .3),
                    ],
                    stops: const [.02, .42, 1],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(pad),
              child: Row(
                children: [
                  avatar,
                  SizedBox(width: gap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EvEyebrow(eyebrow),
                        Semantics(
                          header: true,
                          label: name,
                          excludeSemantics: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                words.take(words.length - 1).join(' '),
                                style: title,
                              ),
                              Text(
                                words.last,
                                style: ev.text.dsp(
                                  title,
                                  weight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        BackdropGroup(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: chips,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (actions.isNotEmpty) ...[
                    SizedBox(width: gap),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final (i, a) in actions.indexed) ...[
                          if (i > 0) const SizedBox(height: 8),
                          a,
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Большой аватар шапки: инициалы на кольце из цветов облика.
///
/// У друга — его цвет вместо кольца и точка состояния в углу.
class EvProfileAvatar extends StatelessWidget {
  const EvProfileAvatar({
    super.key,
    required this.initials,
    this.tint,
    this.status,
  });

  final String initials;

  /// Цвет друга. `null` — своя страница, кольцо из цветов облика.
  final EvAvatarTint? tint;

  /// Точка состояния. `null` — без точки.
  final Color? status;

  static const size = 84.0;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final disc = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: tint != null
            ? LinearGradient(
                begin: const Alignment(-.64, -.77),
                end: const Alignment(.64, .77),
                colors: evAvatarColors(c, tint!),
              )
            // conic-gradient(from 200deg…): у Flutter ноль — на трёх
            // часах, у CSS — на двенадцати.
            : SweepGradient(
                colors: [c.hot2, c.hot1, c.arc, c.hot2],
                transform: const GradientRotation((200 - 90) * math.pi / 180),
              ),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(255, 255, 255, .16),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: c.hot1.withValues(alpha: .4),
            offset: const Offset(0, 12),
            blurRadius: 40,
          ),
        ],
      ),
      child: Text(
        initials,
        style: ev.text.dsp(
          ev.text.display(26),
          weight: FontWeight.w600,
          color: const Color(0xFF0B0B10),
        ),
      ),
    );
    if (status == null) return disc;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          disc,
          Positioned(
            right: 3,
            bottom: 3,
            child: Container(
              width: 17,
              height: 17,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: status,
                border: Border.all(color: c.sub, width: 3),
                boxShadow: status == c.ink4
                    ? null
                    : [BoxShadow(color: status!, blurRadius: 12)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Плашка сводки: подпись, крупное число с хвостом и строка под ним.
/// Горячая — рейтинг раздачи: у магазина такого числа нет, и оно
/// подсвечено как главное.
@immutable
class EvStat {
  const EvStat(
    this.label,
    this.value, {
    this.tail,
    required this.sub,
    this.hot = false,
  }) : hidden = false;

  /// Скрытое остаётся плашкой: на месте числа замок и «скрыто».
  const EvStat.hidden(this.label, {required this.sub})
    : value = 'скрыто',
      tail = null,
      hot = false,
      hidden = true;

  final String label;
  final String value;

  /// «/ 60» после числа — мельче и моноширинным.
  final String? tail;

  final String sub;
  final bool hot;
  final bool hidden;
}

/// Ряд плашек сводки. Колонки от 178 px: на широком окне все в ряд, на
/// узком переносятся. Швы между плашками — не рамки, а одна сетка.
class EvStatTiles extends StatelessWidget {
  const EvStatTiles({super.key, required this.stats});

  final List<EvStat> stats;

  static const minWidth = 178.0;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final value = ev.text.big(
      (MediaQuery.sizeOf(context).width * .03).clamp(26.0, 36.0),
    );
    return Container(
      decoration: BoxDecoration(
        borderRadius: ev.radii.b4,
        border: Border.all(color: c.lineSoft),
      ),
      child: ClipRRect(
        borderRadius: ev.radii.b4,
        child: ColoredBox(
          color: c.lineSoft,
          child: LayoutBuilder(
            builder: (context, box) {
              final columns = ((box.maxWidth + 1) ~/ (minWidth + 1)).clamp(
                1,
                stats.length,
              );
              return Column(
                children: [
                  for (var row = 0; row * columns < stats.length; row++) ...[
                    if (row > 0) const SizedBox(height: 1),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var col = 0; col < columns; col++) ...[
                            if (col > 0) const SizedBox(width: 1),
                            Expanded(
                              child: row * columns + col < stats.length
                                  ? _StatTile(
                                      stat: stats[row * columns + col],
                                      value: value,
                                    )
                                  : ColoredBox(color: c.surface),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat, required this.value});

  final EvStat stat;
  final TextStyle value;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: c.surface,
        gradient: stat.hot
            ? LinearGradient(
                // 160° в CSS
                begin: const Alignment(-.34, -.94),
                end: const Alignment(.34, .94),
                colors: [
                  Color.alphaBlend(c.hot1.withValues(alpha: .1), c.surface),
                  c.surface,
                ],
                stops: const [0, .62],
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stat.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ev.text.data.copyWith(
              fontSize: 9.5,
              letterSpacing: 9.5 * .16,
              color: c.ink4,
            ),
          ),
          const SizedBox(height: 10),
          if (stat.hidden)
            SizedBox(
              height: value.fontSize,
              child: Row(
                children: [
                  EvIcon(EvIcons.lock, size: 16, color: c.ink4),
                  const SizedBox(width: 7),
                  Text(
                    stat.value,
                    style: value.copyWith(
                      fontSize: (MediaQuery.sizeOf(context).width * .02).clamp(
                        18.0,
                        22.0,
                      ),
                      color: c.ink4,
                    ),
                  ),
                ],
              ),
            )
          else
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: stat.value),
                  if (stat.tail != null)
                    TextSpan(
                      text: '  ${stat.tail}',
                      style: ev.text.mono(
                        ev.text.data,
                        size: value.fontSize! * .38,
                        color: c.ink4,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              style: value.copyWith(color: stat.hot ? c.hot2 : c.ink),
            ),
          const SizedBox(height: 9),
          Text(
            stat.sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ev.text.data.copyWith(fontSize: 10, color: c.ink3),
          ),
        ],
      ),
    );
  }
}
