import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../art/key_art.dart';
import '../data/game_facts.dart';
import '../design/ellipse.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../downloads/download_data.dart';
import '../downloads/rate_graph.dart';
import '../friends/ev_avatar.dart';
import '../friends/friends_data.dart';
import '../library/hero_cta.dart';
import '../library/hero_state.dart';
import '../settings/settings_data.dart';
import '../shell/ev_top_bar.dart';
import '../util/plural.dart';
import '../util/units.dart';
import '../widgets/ev_controls.dart';
import '../widgets/ev_icon.dart';
import '../widgets/ev_play_button.dart';
import '../widgets/ev_surfaces.dart';
import 'overlay_data.dart';

/// Оверлей поверх идущей игры: кадры, быстрые действия, достижения
/// сессии, друзья и то, что качается фоном.
///
/// Закрывается «Вернуться в игру», Esc и `Shift+Tab`. «Завершить игру»
/// закрывает оверлей и отдаёт [onQuit].
Future<void> showEvOverlay(
  BuildContext context, {
  required EvSession session,
  required List<EvPerson> friends,
  required int online,
  required EvTorrent? background,
  required VoidCallback onQuit,
}) {
  final reduced = MediaQuery.disableAnimationsOf(context);
  return Navigator.of(context).push(
    _OverlayRoute(
      reduced: reduced,
      page: EvOverlay(
        session: session,
        friends: friends,
        online: online,
        background: background,
        onQuit: onQuit,
      ),
    ),
  );
}

class _OverlayRoute extends PopupRoute<void> {
  _OverlayRoute({required this.page, required this.reduced});

  final Widget page;
  final bool reduced;

  @override
  Color? get barrierColor => null;

  // Барьера не видно — оверлей закрывает всё окно; флаг нужен, чтобы
  // Esc закрывал маршрут.
  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Вернуться в игру';

  @override
  Duration get transitionDuration =>
      reduced ? Duration.zero : const Duration(milliseconds: 280);

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

class EvOverlay extends StatefulWidget {
  const EvOverlay({
    super.key,
    required this.session,
    required this.friends,
    required this.online,
    required this.background,
    required this.onQuit,
  });

  final EvSession session;

  /// Первые четверо в сети и сколько их всего.
  final List<EvPerson> friends;
  final int online;

  /// Раздача, которая качается, пока идёт игра; `null` — ничего.
  final EvTorrent? background;

  final VoidCallback onQuit;

  /// Ширина, уже которой карточка не становится: `minmax(255px, 1fr)`.
  static const cardMin = 255.0;

  @override
  State<EvOverlay> createState() => _EvOverlayState();
}

class _EvOverlayState extends State<EvOverlay>
    with SingleTickerProviderStateMixin {
  static const _step = Duration(milliseconds: 900);

  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(minutes: 1),
    // График идёт по настоящим часам; «меньше движения» его останавливает.
    animationBehavior: AnimationBehavior.preserve,
  )..addListener(_tick);
  late final _frames = EvFrameSeries(widget.session.fps);
  int _ticks = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      // Часы после остановки идут с нуля — счёт шагов тоже.
      _ticks = 0;
      _clock.repeat();
    }
  }

  void _tick() {
    final elapsed = _clock.lastElapsedDuration ?? Duration.zero;
    final steps = elapsed.inMicroseconds ~/ _step.inMicroseconds;
    if (steps == _ticks) return;
    setState(() {
      for (; _ticks < steps; _ticks++) {
        _frames.advance();
      }
    });
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _back() => Navigator.of(context).pop();

  void _quit() {
    Navigator.of(context).pop();
    widget.onQuit();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final shiftTab =
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.tab &&
        HardwareKeyboard.instance.isShiftPressed;
    if (!shiftTab) return KeyEventResult.ignored;
    _back();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final window = MediaQuery.sizeOf(context);
    final low = window.height <= 800;
    // `--pad`: clamp(16px, 2.2vw, 30px), на низком окне — 18.
    final pad = low ? 18.0 : (window.width * .022).clamp(16.0, 30.0);
    final s = widget.session;
    final cards = [
      _PerformanceCard(frames: _frames, session: s, low: low),
      _ActionsCard(session: s),
      _FriendsCard(
        session: s,
        friends: widget.friends,
        online: widget.online,
        background: widget.background,
      ),
    ];
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Material(
        type: MaterialType.transparency,
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: 'Оверлей в игре',
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Backdrop(palette: s.game.palette, seed: s.game.seed + 5),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(session: s, pad: pad),
                  Expanded(
                    child: _Grid(pad: pad, gap: low ? 11 : 14, cards: cards),
                  ),
                  _BottomBar(pad: pad, onBack: _back, onQuit: _quit),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Размытая копия кадра игры под вуалью: оверлей помнит, во что вы
/// играете, но не мешает читать.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.palette, required this.seed});

  final EvCoverPalette palette;
  final int seed;

  /// Холст кадра в прототипе — `makeArt(760, 440, …)`.
  static const _scene = Size(760, 440);

  /// `saturate(1.15)` — матрица насыщенности из спецификации Filter
  /// Effects.
  static const _saturate = <double>[
    1.118, -.1072, -.0108, 0, 0, //
    -.0319, 1.0427, -.0108, 0, 0, //
    -.0319, -.1072, 1.1392, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      // `filter: blur(22px) saturate(1.15)`: радиус в CSS — это и есть
      // сигма; `scale(1.1)` прячет светлую кромку размытия.
      RepaintBoundary(
        child: ClipRect(
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.compose(
              outer: const ColorFilter.matrix(_saturate),
              inner: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            ),
            child: Transform.scale(
              scale: 1.1,
              child: CustomPaint(painter: _ScenePainter(palette, seed)),
            ),
          ),
        ),
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -.1),
            radius: 1,
            transform: EvEllipse(.75, .75, center: Alignment(0, -.1)),
            colors: [
              Color.fromRGBO(6, 6, 10, .74),
              Color.fromRGBO(3, 3, 6, .95),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Кадр игры по `background-size: cover`.
class _ScenePainter extends CustomPainter {
  _ScenePainter(this.palette, this.seed);

  final EvCoverPalette palette;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    const scene = _Backdrop._scene;
    final k = (size.width / scene.width) > (size.height / scene.height)
        ? size.width / scene.width
        : size.height / scene.height;
    canvas
      ..translate(
        (size.width - scene.width * k) / 2,
        (size.height - scene.height * k) / 2,
      )
      ..scale(k);
    paintKeyScene(canvas, scene, palette, seed, ridges: 2);
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.palette != palette || old.seed != seed;
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.session, required this.pad});

  final EvSession session;
  final double pad;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color.fromRGBO(255, 255, 255, .07)),
        ),
      ),
      child: Row(
        children: [
          Text(
            session.game.title.toUpperCase(),
            style: ev.text.dsp(
              ev.text.title,
              size: 13,
              weight: FontWeight.w600,
              letterSpacing: 13 * .14,
            ),
          ),
          const SizedBox(width: 14),
          EvPill('Сессия ${session.length}'),
          const Spacer(),
          EvPill(session.where, dot: false),
          const SizedBox(width: 14),
          const EvKey('Shift+Tab', dense: true),
          const SizedBox(width: 7),
          Text(
            'закрыть оверлей',
            style: ev.text.data.copyWith(fontSize: 10.5, color: c.ink4),
          ),
        ],
      ),
    );
  }
}

/// Карточки сеткой `repeat(auto-fit, minmax(255px, 1fr))`: сколько
/// влезает в ряд, столько и стоит, ряды одной высоты, всё по центру.
class _Grid extends StatelessWidget {
  const _Grid({required this.pad, required this.gap, required this.cards});

  final double pad;
  final double gap;
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final inner = box.maxWidth - pad * 2;
      final columns = ((inner + gap) / (EvOverlay.cardMin + gap)).floor().clamp(
        1,
        cards.length,
      );
      final rows = [
        for (var i = 0; i < cards.length; i += columns)
          cards.sublist(i, (i + columns).clamp(0, cards.length)),
      ];
      return SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: pad, vertical: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final (i, row) in rows.indexed) ...[
                if (i > 0) SizedBox(height: gap),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var k = 0; k < columns; k++) ...[
                        if (k > 0) SizedBox(width: gap),
                        Expanded(
                          child: k < row.length ? row[k] : const SizedBox(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// Карточка оверлея: полупрозрачная панель над размытым кадром.
class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final low = MediaQuery.sizeOf(context).height <= 800;
    return CustomPaint(
      painter: _OuterShadow(ev.radii.r4),
      child: Container(
        padding: EdgeInsets.all(low ? 14 : 17),
        decoration: BoxDecoration(
          borderRadius: ev.radii.b4,
          border: Border.all(color: const Color.fromRGBO(255, 255, 255, .1)),
          color: const Color.fromRGBO(14, 15, 22, .62),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// `box-shadow: 0 20px 60px rgba(0,0,0,.5)` только снаружи карточки.
/// Карточка полупрозрачная, и `BoxShadow` Flutter просвечивал бы сквозь
/// неё тёмной полосой — браузер под элементом тень не рисует.
class _OuterShadow extends CustomPainter {
  const _OuterShadow(this.radius);

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final card = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect((Offset.zero & size).inflate(120))
      ..addRRect(card);
    canvas
      ..save()
      ..clipPath(outside)
      ..drawRRect(
        card.shift(const Offset(0, 20)),
        Paint()
          ..color = const Color.fromRGBO(0, 0, 0, .5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_OuterShadow old) => old.radius != radius;
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.top = 0});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: top, bottom: 9),
    child: Text(text.toUpperCase(), style: context.ev.text.label),
  );
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({
    required this.frames,
    required this.session,
    required this.low,
  });

  final EvFrameSeries frames;
  final EvSession session;
  final bool low;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final small = ev.text.data.copyWith(fontSize: 11, color: c.ink4);
    return _Card(
      children: [
        const _Label('Производительность'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('${frames.fps}', style: ev.text.big(low ? 34 : 42)),
            const SizedBox(width: 12),
            Text('кадров/с', style: small),
            const Spacer(),
            Text(frames.frame, style: small.copyWith(color: EvColors.ok)),
          ],
        ),
        const SizedBox(height: 10),
        Semantics(
          label: 'Кадры в секунду за последнюю минуту',
          child: EvRateGraph.frames(frames.history, height: 56),
        ),
        const SizedBox(height: 14),
        EvKpiGrid(
          items: [
            ('1 % редких', '${session.lowFps}', c.ink),
            ('Видеопамять', '${session.vramGb} ГБ', c.cool),
            ('Температура GPU', '${session.gpuC} °C', c.ink),
            ('Загрузка CPU', '${session.cpu} %', c.ink),
          ],
        ),
      ],
    );
  }
}

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({required this.session});

  final EvSession session;

  /// Быстрые действия и их клавиши. Без движка они ничего не делают —
  /// как и в прототипе.
  static const _actions = [
    (EvIcons.camera, 'Скриншот', 'F12'),
    (EvIcons.rec, 'Записать 30 с', 'F10'),
    (EvIcons.note, 'Заметка', 'F9'),
    (EvIcons.cloud, 'Сохранить в облако', 'F5'),
  ];

  @override
  Widget build(BuildContext context) {
    const found = EvGameFacts.relicsFound, total = EvGameFacts.relicsTotal;
    final collector = EvGameFacts.achievements[EvGameFacts.collector].$1;
    Widget pair(int from) => Row(
      children: [
        Expanded(child: _QuickButton(_actions[from])),
        const SizedBox(width: 8),
        Expanded(child: _QuickButton(_actions[from + 1])),
      ],
    );
    return _Card(
      children: [
        const _Label('Быстрые действия'),
        pair(0),
        const SizedBox(height: 8),
        pair(2),
        const _Label('Достижения в этой сессии', top: 17),
        _SessionAchievement(
          name: session.earned.name,
          detail: 'Получено ${session.earned.when}',
          got: true,
        ),
        ColoredBox(
          color: context.ev.colors.lineSoft,
          child: const SizedBox(height: 1),
        ),
        _SessionAchievement(
          name: '$collector · $found из $total',
          detail:
              'Осталось ${ruCount(total - found, 'реликвия', 'реликвии', 'реликвий')}',
          got: false,
        ),
      ],
    );
  }
}

/// Кнопка быстрого действия: иконка, подпись и клавиша справа.
class _QuickButton extends StatefulWidget {
  const _QuickButton(this.action);

  final (String, String, String) action;

  @override
  State<_QuickButton> createState() => _QuickButtonState();
}

class _QuickButtonState extends State<_QuickButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final (icon, label, key) = widget.action;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: EvMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: ev.radii.b2,
          border: Border.all(
            color: _hover ? c.hot1.withValues(alpha: .45) : c.line,
          ),
          color: _hover
              ? c.hot1.withValues(alpha: .08)
              : c.ink.withValues(alpha: .025),
        ),
        child: Row(
          children: [
            EvIcon(icon, size: 15, color: _hover ? c.ink : c.ink2),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ev.text.body.copyWith(
                  fontSize: 12.5,
                  color: _hover ? c.ink : c.ink2,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Text(
              key,
              style: ev.text.data.copyWith(fontSize: 9.5, color: c.ink4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Строка достижения: полученное светится, остальное — контур.
class _SessionAchievement extends StatelessWidget {
  const _SessionAchievement({
    required this.name,
    required this.detail,
    required this.got,
  });

  final String name;
  final String detail;
  final bool got;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: ev.radii.b4,
              border: Border.all(
                color: got ? c.hot1.withValues(alpha: .45) : c.line,
              ),
              color: got ? c.hot1.withValues(alpha: .1) : null,
              boxShadow: got
                  ? [
                      BoxShadow(
                        color: c.hot1.withValues(alpha: .25),
                        blurRadius: 20,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: EvIcon(
                EvIcons.trophy,
                size: 17,
                color: got ? c.hot2 : c.ink4,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: ev.text.ui(
                    ev.text.body,
                    size: 13,
                    weight: FontWeight.w500,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: ev.text.body.copyWith(fontSize: 11.5, color: c.ink4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendsCard extends StatelessWidget {
  const _FriendsCard({
    required this.session,
    required this.friends,
    required this.online,
    required this.background,
  });

  final EvSession session;
  final List<EvPerson> friends;
  final int online;
  final EvTorrent? background;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final t = background;
    return _Card(
      children: [
        _Label('Друзья · $online в сети'),
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
                    style: ev.text.body.copyWith(fontSize: 12.5, color: c.ink),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  session.lineOf(f),
                  style: ev.text.data.copyWith(fontSize: 10, color: c.ink4),
                ),
              ],
            ),
          ),
        if (t != null) ...[
          const _Label('Фоном', top: 17),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${t.name.split(' · ').first} · ${formatRate(t.downKb ?? 0)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ev.text.data.copyWith(fontSize: 11, color: c.ink4),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${percent(t.progress)} %',
                style: ev.text.data.copyWith(fontSize: 13, color: c.ink),
              ),
            ],
          ),
          const SizedBox(height: 8),
          EvBar(t.progress),
          const SizedBox(height: 10),
          const EvCtaNote(
            EvHeroNote(
              'Загрузка ограничена до ${EvSettings.inGameDownloadMb} МБ/с, '
              'пока игра запущена',
              icon: EvIcons.speed,
              tone: EvNoteTone.cool,
            ),
          ),
        ],
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.pad,
    required this.onBack,
    required this.onQuit,
  });

  final double pad;
  final VoidCallback onBack;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: pad, vertical: 16),
    decoration: const BoxDecoration(
      border: Border(
        top: BorderSide(color: Color.fromRGBO(255, 255, 255, .07)),
      ),
    ),
    child: Row(
      children: [
        EvPlayButton(
          label: 'Вернуться в игру',
          requireHold: false,
          height: 44,
          caption: 'ESC',
          onLaunch: onBack,
        ),
        const SizedBox(width: 14),
        const EvGhostButton(
          label: 'Настройки игры',
          icon: EvIcons.settings,
          height: 44,
          onPressed: null,
        ),
        const Spacer(),
        EvGhostButton(
          label: 'Завершить игру',
          icon: EvIcons.power,
          height: 40,
          danger: true,
          onPressed: onQuit,
        ),
      ],
    ),
  );
}
