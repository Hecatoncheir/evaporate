import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../art/ev_art.dart';
import '../art/key_art.dart';
import '../data/game_facts.dart';
import '../data/sample_data.dart';
import '../data/sample_session.dart';
import '../design/effects.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../glass/ev_glass.dart';
import '../library/hero_cta.dart';
import '../library/hero_state.dart';
import '../util/units.dart';
import '../widgets/ev_controls.dart';
import '../widgets/ev_focusable.dart';
import '../widgets/ev_game_card.dart';
import '../widgets/ev_icon.dart';
import '../widgets/ev_play_button.dart';
import '../widgets/ev_surfaces.dart';
import 'sheet_blocks.dart';

/// Открывает карточку игры — всё, что лаунчер знает об игре, на одном
/// листе поверх окна.
///
/// Главное в ней — липкая полоса действий: она прибита к верху и остаётся
/// на месте при прокрутке, поэтому «Играть» доступно всегда. Удержание
/// в полосе — то же, что в герое, и тем же ритуалом запускает игру
/// ([onLaunch]).
///
/// Закрывается по Esc, кнопкой в углу обложки и кликом мимо листа.
Future<void> showEvGameSheet(
  BuildContext context, {
  required SampleGame game,
  EvHeroState? state,
  VoidCallback? onLaunch,
  VoidCallback? onInstall,
  VoidCallback? onQuit,
  VoidCallback? onOverlay,
}) {
  final reduced = MediaQuery.disableAnimationsOf(context);
  return Navigator.of(context).push(
    _EvSheetRoute(
      game: game,
      state: state,
      onLaunch: onLaunch,
      onInstall: onInstall,
      onQuit: onQuit,
      onOverlay: onOverlay,
      reduced: reduced,
    ),
  );
}

class _EvSheetRoute extends PopupRoute<void> {
  _EvSheetRoute({
    required this.game,
    required this.state,
    required this.onLaunch,
    required this.onInstall,
    required this.onQuit,
    required this.onOverlay,
    required this.reduced,
  });

  final SampleGame game;
  final EvHeroState? state;
  final VoidCallback? onLaunch;
  final VoidCallback? onInstall;
  final VoidCallback? onQuit;
  final VoidCallback? onOverlay;
  final bool reduced;

  CurvedAnimation? _fade;
  CurvedAnimation? _rise;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Закрыть карточку';

  @override
  Duration get transitionDuration =>
      reduced ? Duration.zero : const Duration(milliseconds: 420);

  @override
  Duration get reverseTransitionDuration =>
      reduced ? Duration.zero : EvMotion.fast;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => EvGameSheet(
    game: game,
    state: state,
    onLaunch: onLaunch,
    onInstall: onInstall,
    onQuit: onQuit,
    onOverlay: onOverlay,
  );

  /// Затемнение проявляется за 300 мс, лист за 420 приезжает снизу на
  /// 18 px и дорастает с 98,5 % — `.sheet` и `.sheet-in` в прототипе.
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    _fade ??= CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 300 / 420, curve: EvMotion.ease),
      reverseCurve: Curves.linear,
    );
    _rise ??= CurvedAnimation(
      parent: animation,
      curve: EvMotion.easeOut,
      reverseCurve: Curves.linear,
    );
    return FadeTransition(
      opacity: _fade!,
      child: MatrixTransition(
        animation: _rise!,
        onTransform: (t) {
          final s = .985 + .015 * t;
          return Matrix4.translationValues(0, 18 * (1 - t), 0)
            ..multiply(Matrix4.diagonal3Values(s, s, 1));
        },
        child: child,
      ),
    );
  }

  @override
  void dispose() {
    _fade?.dispose();
    _rise?.dispose();
    super.dispose();
  }
}

/// Карточка игры: обложка с параллаксом, липкая полоса действий и всё,
/// что знает лаунчер, — история, достижения, состав на диске, раздача.
class EvGameSheet extends StatelessWidget {
  const EvGameSheet({
    super.key,
    required this.game,
    this.state,
    this.onLaunch,
    this.onInstall,
    this.onQuit,
    this.onOverlay,
  });

  final SampleGame game;

  /// Состояние игры в окне — у той, что стоит в герое. `null` — читаем
  /// состояние самой раздачи: качается, в очереди, лежит на диске.
  final EvHeroState? state;

  /// Удержание «Играть» в полосе дошло до конца.
  final VoidCallback? onLaunch;

  /// «Установить» и «Обновить и играть».
  final VoidCallback? onInstall;

  /// «Завершить».
  final VoidCallback? onQuit;

  /// «Оверлей» — карточка закрывается, оверлей открывается.
  final VoidCallback? onOverlay;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final window = MediaQuery.sizeOf(context);
    final facts = EvGameFacts.of(game);
    final pad = (window.width * .03).clamp(12.0, 40.0);
    return Stack(
      children: [
        // Мимо листа — закрыть. Окно под карточкой уходит в глубину:
        // размывается и теряет цвет, как под палитрой.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Color.fromRGBO(4, 4, 8, .72),
              ),
              child: BackdropFilter(
                filter: ui.ImageFilter.compose(
                  outer: evGlassColorFilter(0.75, 0.92)!,
                  inner: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(pad),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 1080,
                maxHeight: window.height - pad * 2,
              ),
              child: Semantics(
                scopesRoute: true,
                namesRoute: true,
                explicitChildNodes: true,
                label: 'Карточка игры: ${game.title}',
                child: Material(
                  type: MaterialType.transparency,
                  child: _panel(context, ev, facts, window),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _panel(
    BuildContext context,
    EvTheme ev,
    EvGameFacts facts,
    Size window,
  ) {
    final c = ev.colors;
    final side = (window.width * .03).clamp(18.0, 30.0);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: ev.radii.b5,
        border: Border.all(color: c.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0xCC000000),
            blurRadius: 120,
            offset: Offset(0, 40),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: ev.radii.b5,
        child: CustomScrollView(
          shrinkWrap: true,
          slivers: [
            SliverToBoxAdapter(
              child: _SheetArt(
                game: game,
                facts: facts,
                state: state,
                side: side,
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SheetBarDelegate(
                bar: _SheetBar(
                  game: game,
                  facts: facts,
                  state: state,
                  side: side,
                  onLaunch: () {
                    Navigator.of(context).pop();
                    onLaunch?.call();
                  },
                  onInstall: onInstall == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          onInstall!();
                        },
                  onQuit: onQuit == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          onQuit!();
                        },
                  onOverlay: onOverlay == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          onOverlay!();
                        },
                ),
                // 12 + 46 + 12 и кромка снизу
                height: 71,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  side,
                  (window.width * .026).clamp(18.0, 26.0),
                  side,
                  (window.width * .03).clamp(22.0, 30.0),
                ),
                child: EvSheetBody(game: game, facts: facts, window: window),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Обложка карточки: два слоя из растрового кэша, которые ходят за
/// курсором на 6 и 22 px, затемнение к тексту и заголовок над ним.
///
/// Курсор здесь свой, а не общий с плюмом: слои реагируют на его место
/// внутри обложки, как `pointermove` на `#shArt` в прототипе.
class _SheetArt extends StatefulWidget {
  const _SheetArt({
    required this.game,
    required this.facts,
    required this.state,
    required this.side,
  });

  final SampleGame game;
  final EvGameFacts facts;
  final EvHeroState? state;
  final double side;

  @override
  State<_SheetArt> createState() => _SheetArtState();
}

class _SheetArtState extends State<_SheetArt> {
  final _pointer = ValueNotifier<Offset>(Offset.zero);

  @override
  void dispose() {
    _pointer.dispose();
    super.dispose();
  }

  void _move(PointerEvent event, Size size) {
    if (size.isEmpty) return;
    _pointer.value = Offset(
      event.localPosition.dx / size.width - .5,
      event.localPosition.dy / size.height - .5,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final window = MediaQuery.sizeOf(context);
    final parallax =
        (EvEffectsScope.maybeOf(context)?.parallax ?? false) &&
        !MediaQuery.disableAnimationsOf(context);
    final height = (window.height * .26).clamp(190.0, 280.0);
    final words = widget.game.title.trim().split(' ');
    final head = words.sublist(0, words.length - 1).join(' ');
    final titleSize = (window.width * .034).clamp(26.0, 42.0);
    final titleStyle = ev.text
        .display(titleSize)
        .copyWith(
          height: 1,
          letterSpacing: titleSize * -.025,
          shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 30)],
        );

    return SizedBox(
      height: height,
      // Кадр вписан по «cover» и по высоте вылезает далеко за обложку:
      // `overflow:hidden` в прототипе, обрезка здесь. Без неё он закрывал
      // собой полосу действий.
      child: ClipRect(
        child: Listener(
          onPointerHover: (e) =>
              parallax ? _move(e, Size(window.width, height)) : null,
          child: MouseRegion(
            onExit: (_) => _pointer.value = Offset.zero,
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    painter: _SheetArtPainter(
                      palette: widget.game.palette,
                      seed: widget.game.seed,
                      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                      pointer: parallax ? _pointer : null,
                      surface: c.surface,
                    ),
                  ),
                ),
                Positioned(
                  left: widget.side,
                  right: widget.side,
                  bottom: (window.width * .02).clamp(14.0, 20.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: math.min(640, window.width * .76),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        EvEyebrow(
                          _eyebrow(widget.game, widget.facts, widget.state),
                        ),
                        const SizedBox(height: 9),
                        Semantics(
                          header: true,
                          label: widget.game.title,
                          excludeSemantics: true,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                if (head.isNotEmpty)
                                  TextSpan(text: '$head ', style: titleStyle),
                                TextSpan(
                                  text: words.last,
                                  style: ev.text.dsp(
                                    titleStyle,
                                    weight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final (i, tag) in widget.game.tags.indexed)
                              EvChip(tag, hot: i == 0),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: _CloseButton(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Надглавие читает состояние игры, как в прототипе.
  static String _eyebrow(
    SampleGame game,
    EvGameFacts facts,
    EvHeroState? state,
  ) => switch (state) {
    EvHeroState.running => 'Идёт игра · запущена ${sampleSession.length} назад',
    EvHeroState.installing => 'Установка · осталось 12 мин',
    EvHeroState.update => 'Установлена · доступно обновление',
    EvHeroState.notInstalled => 'В библиотеке · на диске нет',
    _ => switch (game.state) {
      EvGameState.downloading => 'Качается · ${percent(game.progress ?? 0)} %',
      EvGameState.queued => 'В очереди на загрузку',
      EvGameState.ready =>
        facts.hours > 0
            ? 'В библиотеке · сыграно ${facts.hours} ч'
            : 'В библиотеке',
    },
  };
}

/// Кнопка закрытия в углу обложки: 34 px тёмного стекла.
class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: EvFocusable(
        onActivate: widget.onPressed,
        radius: ev.radii.r2,
        child: Semantics(
          button: true,
          label: 'Закрыть',
          child: EvGlass(
            style: EvGlassStyle.chip,
            borderRadius: ev.radii.b2,
            tint: _hover
                ? const Color.fromRGBO(20, 22, 30, .85)
                : const Color.fromRGBO(6, 6, 10, .6),
            child: SizedBox.square(
              dimension: 34,
              child: Center(
                child: EvIcon(
                  EvIcons.close,
                  size: 14,
                  color: _hover ? c.ink : c.ink2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Два слоя обложки: небо и гребни. Растры берутся из общего кэша, кадры
/// параллакса только перекладывают текстуры.
class _SheetArtPainter extends CustomPainter {
  _SheetArtPainter({
    required this.palette,
    required this.seed,
    required this.devicePixelRatio,
    required this.pointer,
    required this.surface,
  }) : super(repaint: pointer);

  final EvCoverPalette palette;
  final int seed;
  final double devicePixelRatio;
  final ValueListenable<Offset>? pointer;

  /// Цвет листа: в него уходит кадр слева и снизу, под текст.
  final Color surface;

  /// Где лежит слой [layer] в обложке размером [size]: запас 5 % с каждой
  /// стороны, сдвиг за курсором и кадр, вписанный по «cover».
  static Rect layerRect(EvSheetLayer layer, Size size, Offset? pointer) {
    const bleed = EvSheetLayer.bleed;
    final box =
        Rect.fromLTRB(
          -size.width * bleed,
          -size.height * bleed,
          size.width * (1 + bleed),
          size.height * (1 + bleed),
        ).shift(
          pointer == null
              ? Offset.zero
              : Offset(
                  -pointer.dx * layer.depth,
                  -pointer.dy * layer.depth * .5,
                ),
        );
    final fit = math.max(
      box.width / EvSheetLayer.scene.width,
      box.height / EvSheetLayer.scene.height,
    );
    return Rect.fromCenter(
      center: box.center,
      width: EvSheetLayer.scene.width * fit,
      height: EvSheetLayer.scene.height * fit,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final p = pointer?.value;
    final paint = Paint()..filterQuality = FilterQuality.low;
    for (final layer in EvSheetLayer.values) {
      final dst = layerRect(layer, size, p);
      final image = EvArtCache.sheetLayer(
        layer,
        palette,
        seed,
        _rasterScale(dst.width / EvSheetLayer.scene.width * devicePixelRatio),
      );
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        dst,
        paint,
      );
    }

    final w = size.width, h = size.height;
    final full = Offset.zero & size;
    canvas
      ..drawRect(
        full,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(w, 0),
            [
              surface,
              const Color.fromRGBO(14, 15, 22, .8),
              const Color.fromRGBO(14, 15, 22, .1),
              const Color.fromRGBO(14, 15, 22, 0),
            ],
            const [.01, .34, .68, 1],
          ),
      )
      ..drawRect(
        full,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, h),
            Offset.zero,
            [surface, surface.withValues(alpha: 0)],
            const [.02, .62],
          ),
      );
  }

  /// Масштаб растра ступенями по четверти, как у героя.
  static double _rasterScale(double pixelsPerScenePixel) =>
      (pixelsPerScenePixel * 4).ceil().clamp(2, 10) / 4;

  @override
  bool shouldRepaint(_SheetArtPainter old) =>
      old.palette != palette ||
      old.seed != seed ||
      old.devicePixelRatio != devicePixelRatio ||
      old.pointer != pointer ||
      old.surface != surface;
}

/// Липкая полоса действий. Читает состояние игры: установленную можно
/// запустить удержанием, качающуюся — поставить на паузу, из очереди —
/// скачать сейчас.
class _SheetBar extends StatelessWidget {
  const _SheetBar({
    required this.game,
    required this.facts,
    required this.state,
    required this.side,
    required this.onLaunch,
    required this.onInstall,
    required this.onQuit,
    required this.onOverlay,
  });

  final SampleGame game;
  final EvGameFacts facts;
  final EvHeroState? state;
  final double side;
  final VoidCallback onLaunch;
  final VoidCallback? onInstall;
  final VoidCallback? onQuit;
  final VoidCallback? onOverlay;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final effects = EvEffectsScope.maybeOf(context);
    final where = ev.text.data.copyWith(fontSize: 10.5, color: c.ink4);
    final whereStrong = ev.text.data.copyWith(
      fontSize: 10.5,
      color: c.ink2,
      fontWeight: FontWeight.w500,
    );

    Widget hint(List<(String, bool)> parts) => Text.rich(
      TextSpan(
        children: [
          for (final (text, strong) in parts)
            TextSpan(text: text, style: strong ? whereStrong : where),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final actions = <Widget>[];
    Widget? progress;

    // Состояние окна сильнее состояния раздачи: игра идёт — в полосе
    // статус, идёт установка — прогресс. Так же решает `cardState`.
    switch (state) {
      case EvHeroState.running:
        actions.addAll([
          EvRunningPill(sampleSession.clock, height: 46),
          EvGhostButton(
            label: 'Оверлей',
            icon: EvIcons.library,
            height: 46,
            onPressed: onOverlay,
          ),
          EvGhostButton(
            label: 'Завершить',
            icon: EvIcons.power,
            height: 46,
            danger: true,
            onPressed: onQuit,
          ),
          const Spacer(),
          hint([
            ('${sampleSession.chapter} · ', false),
            (sampleSession.place, true),
          ]),
        ]);
        return _wrap(context, c, actions, null);
      case EvHeroState.installing:
        actions.addAll([
          const EvRunningPill(
            '41 %',
            label: 'Установка',
            height: 46,
            hot: true,
          ),
          EvGhostButton(
            label: 'Пауза',
            icon: EvIcons.pause,
            height: 46,
            onPressed: null,
          ),
          EvGhostButton(
            label: 'Отменить',
            icon: EvIcons.close,
            height: 46,
            danger: true,
            onPressed: null,
          ),
          const Spacer(),
          hint([('28.0 из 68.4 ГБ · ', false), ('осталось 12 мин', true)]),
        ]);
        return _wrap(context, c, actions, const EvBar(.41, height: 2));
      case EvHeroState.update:
        actions.addAll([
          EvPlayButton(
            label: 'Обновить и играть',
            icon: EvIcons.download,
            caption: '1.8 ГБ',
            height: 46,
            requireHold: false,
            onLaunch: onInstall,
          ),
          EvGhostButton(
            label: 'Без обновления',
            icon: EvIcons.play,
            height: 46,
            onPressed: onLaunch,
          ),
          ..._icons(context),
          const Spacer(),
          hint([('установлена ', false), (game.bareVersion, true)]),
        ]);
        return _wrap(context, c, actions, null);
      case EvHeroState.notInstalled:
        actions.addAll([
          EvPlayButton(
            label: 'Установить',
            icon: EvIcons.download,
            caption: game.size.toUpperCase(),
            height: 46,
            requireHold: false,
            onLaunch: onInstall,
          ),
          EvGhostButton(
            label: 'Указать папку',
            icon: EvIcons.folder,
            height: 46,
            onPressed: null,
          ),
          const Spacer(),
          hint([('свободно ', false), ('214 ГБ', true)]),
        ]);
        return _wrap(context, c, actions, null);
      case EvHeroState.ready:
      case EvHeroState.offline:
      case EvHeroState.returned:
      case null:
        break;
    }

    switch (game.state) {
      case EvGameState.ready:
        actions.addAll([
          EvPlayButton(
            height: 46,
            requireHold: effects?.holdToPlay ?? true,
            onLaunch: onLaunch,
          ),
          ..._icons(context),
          const Spacer(),
          hint(
            facts.hours > 0
                ? [('Глава 5 · ', false), ('62 %', true)]
                : [('ещё не запускали', false)],
          ),
        ]);
      case EvGameState.downloading:
        actions.addAll([
          EvPlayButton(
            label: 'Идёт загрузка',
            icon: EvIcons.download,
            caption: '${percent(game.progress ?? 0)} %',
            cool: true,
            height: 46,
            requireHold: false,
            onLaunch: null,
          ),
          EvGhostButton(
            label: 'Пауза',
            icon: EvIcons.pause,
            height: 46,
            onPressed: null,
          ),
          ..._icons(context),
          const Spacer(),
          hint([
            ('сиды ', false),
            ('${facts.peers ~/ 2 + 13}', true),
            (' · пиры ', false),
            ('${facts.peers + 9}', true),
          ]),
        ]);
        progress = EvBar(game.progress ?? 0, cool: true, height: 2);
      case EvGameState.queued:
        actions.addAll([
          EvPlayButton(
            label: 'Скачать сейчас',
            icon: EvIcons.download,
            caption: game.size.toUpperCase(),
            height: 46,
            requireHold: false,
            onLaunch: null,
          ),
          EvGhostButton(
            label: 'Убрать из очереди',
            icon: EvIcons.close,
            height: 46,
            danger: true,
            onPressed: null,
          ),
          const Spacer(),
          hint([('в очереди · ', false), ('вторая', true)]),
        ]);
    }

    return _wrap(context, c, actions, progress);
  }

  /// Стекло полосы: почти непрозрачное — `rgba(14,15,22,.94)`
  /// в прототипе, — под ним проезжает текст, и он не должен читаться
  /// сквозь него.
  Widget _wrap(
    BuildContext context,
    EvColors c,
    List<Widget> actions,
    Widget? progress,
  ) => EvGlass(
    style: EvGlassStyle.frost,
    borderRadius: BorderRadius.zero,
    tint: c.surface.withValues(alpha: .94),
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.lineSoft)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: side, vertical: 12),
            child: Row(
              children: [
                for (final (i, action) in actions.indexed) ...[
                  if (i > 0 && action is! Spacer) const SizedBox(width: 9),
                  action,
                ],
              ],
            ),
          ),
          if (progress != null)
            Positioned(left: 0, right: 0, bottom: 0, child: progress),
        ],
      ),
    ),
  );

  /// Три глагола, которые нужны чаще всего, — иконками.
  List<Widget> _icons(BuildContext context) => const [
    EvGhostButton.icon(
      icon: EvIcons.verified,
      label: 'Проверить файлы',
      height: 46,
      onPressed: null,
    ),
    EvGhostButton.icon(
      icon: EvIcons.folder,
      label: 'Открыть папку',
      height: 46,
      onPressed: null,
    ),
    EvGhostButton.icon(
      icon: EvIcons.settings,
      label: 'Настройки запуска',
      height: 46,
      onPressed: null,
    ),
  ];
}

class _SheetBarDelegate extends SliverPersistentHeaderDelegate {
  _SheetBarDelegate({required this.bar, required this.height});

  final Widget bar;
  final double height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox(height: height, child: bar);

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(_SheetBarDelegate old) =>
      old.bar != bar || old.height != height;
}
