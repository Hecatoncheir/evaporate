import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../art/ev_art.dart';
import '../art/key_art.dart';
import '../data/game_facts.dart';
import '../data/sample_data.dart';
import '../design/ellipse.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../sound/ev_sound.dart';
import '../sound/voices.dart';
import '../widgets/ev_controls.dart';
import '../widgets/ev_focusable.dart';
import '../widgets/ev_game_card.dart';
import '../widgets/ev_icon.dart';
import '../widgets/ev_play_button.dart';
import '../widgets/ev_surfaces.dart';

/// Режим «Пульт» — весь экран для дивана и геймпада: карусель из пяти
/// обложек, фон из размытой копии выбранной, крупные кнопки и подсказки
/// по кнопкам геймпада вместо клавиш.
///
/// `←` `→` листают, `Enter` запускает, `Esc` выходит. «Играть» и
/// «Подробнее» закрывают пульт и отдают игру в [onPlay] и [onDetails].
Future<void> showEvPult(
  BuildContext context, {
  required List<SampleGame> games,
  required String rate,
  required String initials,
  required ValueChanged<SampleGame> onPlay,
  required ValueChanged<SampleGame> onDetails,
}) {
  final reduced = MediaQuery.disableAnimationsOf(context);
  return Navigator.of(context).push(
    _PultRoute(
      reduced: reduced,
      page: EvPult(
        games: games,
        rate: rate,
        initials: initials,
        onPlay: onPlay,
        onDetails: onDetails,
      ),
    ),
  );
}

class _PultRoute extends PopupRoute<void> {
  _PultRoute({required this.page, required this.reduced});

  final Widget page;
  final bool reduced;

  @override
  Color? get barrierColor => null;

  // Барьера не видно — пульт закрывает всё окно; флаг нужен, чтобы Esc
  // закрывал маршрут.
  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Выйти из режима';

  @override
  Duration get transitionDuration =>
      reduced ? Duration.zero : const Duration(milliseconds: 380);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => page;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: EvMotion.ease),
    child: child,
  );
}

/// Что делает большая кнопка пульта: в игру, в которую уже играли, —
/// «Продолжить», в новую — «Играть», в то, чего нет на диске, — в
/// загрузки.
String evPultAction(SampleGame game) {
  if (game.state != EvGameState.ready) return 'К загрузкам';
  return EvGameFacts.of(game).hours > 0 ? 'Продолжить' : 'Играть';
}

/// Строка под названием: сколько сыграно или что с игрой, и размер.
String evPultLine(SampleGame game) {
  final hours = EvGameFacts.of(game).hours;
  return hours > 0
      ? 'сыграно $hours ч · ${game.size}'
      : '${game.subtitle} · ${game.size}';
}

class EvPult extends StatefulWidget {
  const EvPult({
    super.key,
    required this.games,
    required this.rate,
    required this.initials,
    required this.onPlay,
    required this.onDetails,
  });

  final List<SampleGame> games;

  /// Приём сейчас — та же плашка, что в верхней полосе окна.
  final String rate;
  final String initials;
  final ValueChanged<SampleGame> onPlay;
  final ValueChanged<SampleGame> onDetails;

  @override
  State<EvPult> createState() => _EvPultState();
}

class _EvPultState extends State<EvPult> {
  int _index = 0;

  SampleGame _at(int offset) {
    final n = widget.games.length;
    return widget.games[((_index + offset) % n + n) % n];
  }

  void _step(int by) {
    EvSoundScope.maybeOf(context)?.play(EvVoice.tick);
    setState(() => _index += by);
  }

  void _play() {
    final g = _at(0);
    Navigator.of(context).pop();
    widget.onPlay(g);
  }

  void _details() {
    final g = _at(0);
    Navigator.of(context).pop();
    widget.onDetails(g);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight) {
      _step(1);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _step(-1);
    } else if (key == LogicalKeyboardKey.enter && event is KeyDownEvent) {
      _play();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ev.colors;
    final g = _at(0);
    final n = widget.games.length;
    final position = ((_index % n) + n) % n + 1;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Material(
        type: MaterialType.transparency,
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: 'Режим Пульт',
          child: ColoredBox(
            color: c.ground,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _PultBackdrop(game: g),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PultTop(
                      position: '$position / $n',
                      rate: widget.rate,
                      initials: widget.initials,
                    ),
                    Expanded(
                      child: Center(
                        child: _Flow(
                          covers: [for (var k = -2; k <= 2; k++) _at(k)],
                          onStep: _step,
                        ),
                      ),
                    ),
                    _PultInfo(game: g, onPlay: _play, onDetails: _details),
                    const _Pads(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Размытая копия выбранной игры под виньеткой: тема экрана меняется
/// вместе с выбором.
class _PultBackdrop extends StatelessWidget {
  const _PultBackdrop({required this.game});

  final SampleGame game;

  /// `saturate(1.35)` — матрица насыщенности из спецификации Filter
  /// Effects.
  static const _saturate = <double>[
    1.2755, -.2503, -.0252, 0, 0, //
    -.0746, 1.0998, -.0252, 0, 0, //
    -.0746, -.2503, 1.3248, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      // `filter: blur(34px) saturate(1.35); transform: scale(1.18);
      // opacity: .5` — смена игры проявляется за 500 мс.
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: RepaintBoundary(
          key: ValueKey(game.title),
          child: Opacity(
            opacity: .5,
            child: ClipRect(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.compose(
                  outer: const ColorFilter.matrix(_saturate),
                  inner: ui.ImageFilter.blur(sigmaX: 34, sigmaY: 34),
                ),
                child: Transform.scale(
                  scale: 1.18,
                  child: CustomPaint(
                    painter: _PultArt(game.palette, game.seed),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -.12),
            radius: 1,
            transform: EvEllipse(.64, .72, center: Alignment(0, -.12)),
            colors: [Color(0x00040408), Color.fromRGBO(4, 4, 8, .94)],
          ),
        ),
      ),
    ],
  );
}

/// Кадр фона: `makeArt(600, 380, …, {ridges: 1, sx: .5, sy: .4})`.
class _PultArt extends CustomPainter {
  _PultArt(this.palette, this.seed);

  final EvCoverPalette palette;
  final int seed;

  static const _scene = Size(600, 380);

  @override
  void paint(Canvas canvas, Size size) {
    final k = math.max(size.width / _scene.width, size.height / _scene.height);
    canvas
      ..translate(
        (size.width - _scene.width * k) / 2,
        (size.height - _scene.height * k) / 2,
      )
      ..scale(k);
    paintKeyScene(
      canvas,
      _scene,
      palette,
      seed + 23,
      ridges: 1,
      sunX: .5,
      sunY: .4,
    );
  }

  @override
  bool shouldRepaint(_PultArt old) =>
      old.palette != palette || old.seed != seed;
}

class _PultTop extends StatelessWidget {
  const _PultTop({
    required this.position,
    required this.rate,
    required this.initials,
  });

  final String position;
  final String rate;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final side = (MediaQuery.sizeOf(context).width * .04).clamp(22.0, 48.0);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: side, vertical: 22),
      child: Row(
        children: [
          Text(
            'EVAPORATE',
            style: ev.text.dsp(
              ev.text.section,
              size: 12,
              weight: FontWeight.w600,
              letterSpacing: 12 * .2,
            ),
          ),
          const SizedBox(width: 14),
          EvPill(position),
          const Spacer(),
          EvPill(rate, status: EvStatus.busy),
          const SizedBox(width: 14),
          EvPill(initials, status: EvStatus.news, dot: false),
        ],
      ),
    );
  }
}

/// Пять обложек: выбранная крупно в середине, по две с боков — мельче
/// и тусклее. По боковым можно кликать.
class _Flow extends StatelessWidget {
  const _Flow({required this.covers, required this.onStep});

  final List<SampleGame> covers;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final w = MediaQuery.sizeOf(context).width;
    final mid = (w * .17).clamp(170.0, 248.0);
    final side = (w * .09).clamp(84.0, 132.0);
    final gap = (w * .024).clamp(14.0, 30.0);
    Widget cover(int k, SampleGame g) {
      final center = k == 0;
      final width = center ? mid : side;
      final art = Container(
        width: width,
        height: width * 4 / 3,
        decoration: BoxDecoration(
          borderRadius: ev.radii.b4,
          border: Border.all(
            color: center ? c.hot1.withValues(alpha: .5) : c.line,
          ),
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, center ? .78 : .6),
              blurRadius: center ? 76 : 40,
              offset: Offset(0, center ? 34 : 20),
            ),
            if (center)
              BoxShadow(color: c.hot1.withValues(alpha: .3), blurRadius: 70),
          ],
        ),
        child: ClipRRect(
          borderRadius: ev.radii.b4,
          child: EvCover(palette: g.palette, seed: g.seed),
        ),
      );
      if (center) return art;
      return Opacity(
        opacity: .34,
        child: Transform.scale(
          scale: .84,
          child: EvFocusable(
            onActivate: () => onStep(k),
            radius: ev.radii.r4,
            child: Semantics(
              button: true,
              label: g.title,
              excludeSemantics: true,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(onTap: () => onStep(k), child: art),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, g) in covers.indexed) ...[
          if (i > 0) SizedBox(width: gap),
          cover(i - 2, g),
        ],
      ],
    );
  }
}

class _PultInfo extends StatelessWidget {
  const _PultInfo({
    required this.game,
    required this.onPlay,
    required this.onDetails,
  });

  final SampleGame game;
  final VoidCallback onPlay;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final w = MediaQuery.sizeOf(context).width;
    final size = (w * .044).clamp(28.0, 58.0);
    final side = (w * .04).clamp(22.0, 48.0);
    final words = game.title.split(' ');
    final light = words.length > 1
        ? '${words.sublist(0, words.length - 1).join(' ')} '
        : '';
    final title = ev.text
        .dsp(
          ev.text.section,
          size: size,
          weight: FontWeight.w300,
          letterSpacing: size * -.03,
        )
        .copyWith(height: .96, color: c.ink);
    return Padding(
      padding: EdgeInsets.fromLTRB(side, 0, side, (w * .02).clamp(14.0, 26.0)),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (label, hot) in game.chips.take(3))
                EvChip(label, hot: hot),
            ],
          ),
          const SizedBox(height: 15),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: light),
                TextSpan(
                  text: words.last,
                  style: ev.text.dsp(title, weight: FontWeight.w800),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: title,
          ),
          const SizedBox(height: 15),
          Text(
            evPultLine(game),
            style: ev.text.data.copyWith(fontSize: 11.5, color: c.ink3),
          ),
          const SizedBox(height: 15),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              EvPlayButton(
                label: evPultAction(game),
                requireHold: false,
                height: 52,
                onLaunch: onPlay,
              ),
              EvGhostButton(
                label: 'Подробнее',
                icon: EvIcons.info,
                height: 52,
                onPressed: onDetails,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Подсказки по кнопкам геймпада.
class _Pads extends StatelessWidget {
  const _Pads();

  static const _pads = [
    ('A', 'Запустить'),
    ('X', 'Подробнее'),
    ('◄ ►', 'Выбор игры'),
    ('Y', 'Поиск'),
    ('B', 'Выйти из режима'),
  ];

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final gap = (MediaQuery.sizeOf(context).width * .03).clamp(16.0, 34.0);
    final text = ev.text.data.copyWith(fontSize: 10.5, color: c.ink4);
    Widget pad(String key) {
      final tint = switch (key) {
        'A' => EvColors.ok,
        'X' => c.cool,
        _ => null,
      };
      return Container(
        constraints: const BoxConstraints(minWidth: 19),
        height: 19,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tint?.withValues(alpha: .5) ?? c.line),
        ),
        child: Text(
          key,
          style: text.copyWith(fontSize: 9, color: tint ?? c.ink3),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color.fromRGBO(255, 255, 255, .07)),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: gap,
        runSpacing: 8,
        children: [
          for (final (key, label) in _pads)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                pad(key),
                const SizedBox(width: 8),
                Text(label, style: text),
              ],
            ),
        ],
      ),
    );
  }
}
