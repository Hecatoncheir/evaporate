import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../atmosphere/ember_field.dart';
import '../atmosphere/ember_paint.dart';
import '../design/effects.dart';
import '../design/theme.dart';
import '../sound/ev_sound.dart';
import '../sound/voices.dart';
import 'ritual_core.dart';
import 'ritual_timeline.dart';

/// Стадия ритуала: подпись над названием и строка журнала под полосой.
typedef EvLaunchStage = (String title, String log);

/// Запускает игру [title] — ритуал запуска поверх всего окна.
///
/// Полный ритуал идёт по [EvRitualTiming]: стадии [stages] за 2,6 с,
/// выброс искр, вспышка, ударная волна и ирис, который возвращает окно.
/// Выключен в «Настройках → Эффекты» или включено «уменьшить движение» —
/// короткое затемнение с ядром и названием на 0,9 с, без выброса, вспышки
/// и движения.
///
/// Ритуал модален: клавиши и курсор до окна под ним не доходят. Будущее
/// завершается, когда затемнение начинает уходить.
Future<void> showEvLaunchRitual(
  BuildContext context, {
  required String title,
  required List<EvLaunchStage> stages,
}) {
  assert(stages.isNotEmpty, 'ритуалу нужна хотя бы одна стадия');
  final effects = EvEffectsScope.maybeOf(context);
  final still = MediaQuery.disableAnimationsOf(context);
  final full = (effects?.ritual ?? true) && !still;
  // Ритуал звучит, только когда он виден; короткое затемнение отвечает
  // «Готово».
  EvSoundScope.maybeOf(context)?.play(full ? EvVoice.ritual : EvVoice.ok);
  return Navigator.of(context).push(
    _EvRitualRoute(
      title: title,
      stages: stages,
      full: full,
      still: still,
      sparks: full && (effects?.sparks ?? false),
      quality: effects?.quality ?? EvEffectsQuality.full,
    ),
  );
}

/// Маршрут ритуала. Пока пустота закрывает окно целиком — от конца
/// проявления до удара, — маршрут непрозрачен, и страницы под ним не
/// рисуются и не тратят кадры: атмосфера за пустотой никому не видна.
class _EvRitualRoute extends PopupRoute<void> {
  _EvRitualRoute({
    required this.title,
    required this.stages,
    required this.full,
    required this.still,
    required this.sparks,
    required this.quality,
  });

  final String title;
  final List<EvLaunchStage> stages;
  final bool full;
  final bool still;
  final bool sparks;
  final EvEffectsQuality quality;

  bool _covered = true;
  CurvedAnimation? _fade;

  // TransitionRoute сам делает маршрут непрозрачным, когда проявление
  // закончилось, и прозрачным, когда затемнение уходит.
  @override
  bool get opaque => _covered;

  /// Удар: ирис открывает окно, и его снова нужно рисовать.
  void _uncover() {
    if (!_covered) return;
    _covered = false;
    if (overlayEntries.isNotEmpty) overlayEntries.first.opaque = false;
  }

  void _finish() {
    if (!isActive) return;
    if (isCurrent) {
      navigator!.pop();
    } else {
      navigator!.removeRoute(this);
    }
  }

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration =>
      still ? Duration.zero : EvRitualTiming.fade;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => EvLaunchRitual(
    title: title,
    stages: stages,
    full: full,
    still: still,
    sparks: sparks,
    quality: quality,
    onStrike: _uncover,
    onDone: _finish,
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(
    opacity: _fade ??= CurvedAnimation(
      parent: animation,
      curve: EvRitualTiming.fadeIn,
      reverseCurve: EvRitualTiming.fadeOut,
    ),
    child: child,
  );

  @override
  void dispose() {
    _fade?.dispose();
    super.dispose();
  }
}

/// Ритуал запуска — перенос `.launch` прототипа: затемнение с ирисом,
/// искры, ударная волна, ядро с названием и стадиями, вспышка поверх.
///
/// Обычно показывается через [showEvLaunchRitual]; сам виджет только
/// отсчитывает время и сообщает об ударе ([onStrike]) и о конце
/// ([onDone]). Состояние к концу не сбрасывается: затемнение уходит
/// с раскрытым ирисом и полной полосой. В прототипе сброс шёл до ухода,
/// и окно на 300 мс снова закрывала пустота с «Подготовкой среды».
class EvLaunchRitual extends StatefulWidget {
  const EvLaunchRitual({
    super.key,
    required this.title,
    required this.stages,
    this.full = true,
    this.still = false,
    this.sparks = false,
    this.quality = EvEffectsQuality.full,
    this.onStrike,
    this.onDone,
  });

  /// Название игры. Последнее слово набирается жирным.
  final String title;

  final List<EvLaunchStage> stages;

  /// Полный ритуал; `false` — короткое затемнение на 0,9 с.
  final bool full;

  /// «Уменьшить движение»: кольца стоят, шар не дышит.
  final bool still;

  /// Выброс искр: только в полном ритуале и при включённых искрах.
  final bool sparks;

  /// Уровень эффектов: сколько искр.
  final EvEffectsQuality quality;

  /// Удар: вспышка, волна, ирис начинает раскрываться.
  final VoidCallback? onStrike;

  /// Пора убирать затемнение.
  final VoidCallback? onDone;

  @override
  State<EvLaunchRitual> createState() => EvLaunchRitualState();
}

class EvLaunchRitualState extends State<EvLaunchRitual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;
  final _elapsed = ValueNotifier<Duration>(Duration.zero);
  final _progress = ValueNotifier<double>(0);
  final _stage = ValueNotifier<int>(0);
  final _iris = ValueNotifier<double>(0);
  final _flash = ValueNotifier<double>(0);
  final _shock = ValueNotifier<double?>(null);

  EvEmberField? _embers;
  ui.Image? _sprite;
  Duration _last = Duration.zero;
  bool _struck = false;
  bool _done = false;

  /// Искры ритуала — для тестов.
  @visibleForTesting
  EvEmberField? get embers => _embers;

  /// Радиус отверстия ириса — для тестов.
  @visibleForTesting
  double get iris => _iris.value;

  Duration get _end => widget.full ? EvRitualTiming.full : EvRitualTiming.brief;

  @override
  void initState() {
    super.initState();
    // Часы идут и во время ухода затемнения: искры не должны застыть.
    // Это отсчёт, а не анимация: при «уменьшить движение» обычный
    // контроллер шёл бы в двадцать раз быстрее, и затемнение мелькало бы
    // на 45 мс вместо 900.
    _clock = AnimationController(
      vsync: this,
      duration: _end + (widget.still ? Duration.zero : EvRitualTiming.fade),
      animationBehavior: AnimationBehavior.preserve,
    )..addListener(_tick);
    if (widget.sparks) {
      _embers = EvEmberField();
      _sprite = makeEvEmberSprite();
    }
    _clock.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final embers = _embers;
    if (embers == null) return;
    // Размер окна известен только здесь. Первый раз искры рождаются по
    // нижним двум третям окна — там, где живут угли атмосферы, — и сразу
    // срываются вверх; при смене размера рождаются заново обычными.
    final first = embers.embers.isEmpty;
    embers.resize(MediaQuery.sizeOf(context), widget.quality.factor);
    if (first) embers.burst();
  }

  @override
  void dispose() {
    _clock.dispose();
    _elapsed.dispose();
    _progress.dispose();
    _stage.dispose();
    _iris.dispose();
    _flash.dispose();
    _shock.dispose();
    _sprite?.dispose();
    super.dispose();
  }

  void _tick() {
    final now = _clock.duration! * _clock.value;
    _embers?.step((now - _last).inMicroseconds / 1e6);
    _last = now;
    if (!widget.still) _elapsed.value = now;
    if (widget.full) {
      final frame = EvRitualFrame.at(now);
      _progress.value = frame.progress;
      _stage.value = frame.stage(widget.stages.length);
      _iris.value = frame.iris;
      _flash.value = frame.flash;
      _shock.value = frame.shock;
      if (frame.struck && !_struck) {
        _struck = true;
        widget.onStrike?.call();
      }
    }
    if (now >= _end && !_done) {
      _done = true;
      widget.onDone?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.evc;
    final embers = _embers;
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Запуск: ${widget.title}',
      // Без Material текст маршрута получил бы стиль-заглушку Flutter —
      // жёлтое двойное подчёркивание.
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                painter: _VeilPainter(iris: _iris, ground: c.ground),
              ),
            ),
            if (embers != null)
              RepaintBoundary(
                child: CustomPaint(
                  painter: _EmbersPainter(
                    repaint: _elapsed,
                    embers: embers,
                    sprite: _sprite!,
                    hot: c.hot2,
                    cool: c.cool,
                  ),
                ),
              ),
            if (widget.full)
              CustomPaint(
                painter: _ShockPainter(shock: _shock, color: c.hot1),
              ),
            Center(child: _content(context)),
            if (widget.full)
              IgnorePointer(
                child: ValueListenableBuilder<double>(
                  valueListenable: _flash,
                  builder: (context, flash, _) => flash <= 0
                      ? const SizedBox.shrink()
                      : ColoredBox(
                          color: const Color(0xFFFFFFFF)
                              .withValues(alpha: flash),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// `.lz`: ядро, стадия с названием, полоса и журнал с зазорами по 22 px.
  Widget _content(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final window = MediaQuery.sizeOf(context);

    // clamp(22px, 3.4vw, 38px), разрядка −.02em, строка — 1.5 кегля
    final titleSize = (window.width * .034).clamp(22.0, 38.0);
    final light = ev.text
        .display(titleSize)
        .copyWith(
          height: 1.5,
          letterSpacing: titleSize * -.02,
          leadingDistribution: TextLeadingDistribution.even,
        );
    final bold = ev.text
        .displayBold(titleSize)
        .copyWith(
          height: 1.5,
          letterSpacing: titleSize * -.02,
          leadingDistribution: TextLeadingDistribution.even,
        );
    final words = widget.title.trim().split(' ');
    final head = words.sublist(0, words.length - 1).join(' ');

    final stageStyle = ev.text.data.copyWith(
      fontSize: 11,
      height: 1.5,
      letterSpacing: 11 * .24,
      color: c.hot2,
      leadingDistribution: TextLeadingDistribution.even,
    );
    final logStyle = ev.text.data.copyWith(
      fontSize: 10.5,
      height: 1.5,
      color: c.ink4,
      leadingDistribution: TextLeadingDistribution.even,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EvRitualCore(
            elapsed: _elapsed,
            progress: _progress,
            still: widget.still,
          ),
          const SizedBox(height: 22),
          // Строка — 16,5, как в CSS: абзац округлил бы её до 17 и сдвинул
          // ядро на четверть пикселя.
          SizedBox(
            height: 16.5,
            child: ValueListenableBuilder<int>(
              valueListenable: _stage,
              builder: (context, i, _) => Text(
                widget.stages[i].$1.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 1,
                style: stageStyle,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: [
                if (head.isNotEmpty) TextSpan(text: '$head ', style: light),
                TextSpan(text: words.last, style: bold),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          CustomPaint(
            size: Size(math.min(340, window.width * .7), 2),
            painter: _BarPainter(
              progress: _progress,
              hot1: c.hot1,
              hot2: c.hot2,
              radius: ev.radii.r4,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 16,
            child: ValueListenableBuilder<int>(
              valueListenable: _stage,
              builder: (context, i, _) => Text(
                widget.stages[i].$2,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: logStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Затемнение `.launch` и ирис `.iris` над ним.
///
/// * `radial-gradient(70% 70% at 50% 52%, rgba(8,4,2,.5), rgba(3,3,6,.97))` —
///   виньетка, сквозь которую окно видно, когда ирис раскрыт;
/// * `radial-gradient(circle at 50% 50%, transparent k, void k+1%)` —
///   пустота с отверстием, проценты — от расстояния до дальнего угла.
class _VeilPainter extends CustomPainter {
  _VeilPainter({required this.iris, required this.ground})
    : super(repaint: iris);

  final ValueListenable<double> iris;
  final Color ground;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final w = size.width, h = size.height;

    final center = Offset(w * .5, h * .52);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          1,
          const [Color.fromRGBO(8, 4, 2, .5), Color.fromRGBO(3, 3, 6, .97)],
          const [0, 1],
          TileMode.clamp,
          (Matrix4.translationValues(
            center.dx,
            center.dy,
            0,
          )..multiply(Matrix4.diagonal3Values(w * .7, h * .7, 1))).storage,
        ),
    );

    final k = iris.value;
    if (k >= 1) return;
    // До удара — сплошная пустота. Градиент с отверстием в 0 % оставлял
    // посередине окна мягкую точку в 17 px, сквозь которую было видно окно.
    if (k <= 0) {
      canvas.drawRect(rect, Paint()..color = ground);
      return;
    }
    final far = size.center(Offset.zero).distance;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          size.center(Offset.zero),
          (k + .01) * far,
          [ground.withValues(alpha: 0), ground],
          [k / (k + .01), 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_VeilPainter old) =>
      old.iris != iris || old.ground != ground;
}

/// Искры ритуала над пустотой, под ядром и текстом. В прототипе выброс
/// шёл на холсте углей под интерфейсом, а через 300 мс его закрывала
/// пустота — испарения интерфейса не было видно вовсе.
class _EmbersPainter extends CustomPainter {
  _EmbersPainter({
    required Listenable repaint,
    required this.embers,
    required this.sprite,
    required this.hot,
    required this.cool,
  }) : super(repaint: repaint);

  final EvEmberField embers;
  final ui.Image sprite;
  final Color hot;
  final Color cool;

  @override
  void paint(Canvas canvas, Size size) => paintEvEmbers(
    canvas,
    embers.embers,
    sprite: sprite,
    hot: hot,
    cool: cool,
  );

  @override
  bool shouldRepaint(_EmbersPainter old) =>
      old.embers != embers ||
      old.sprite != sprite ||
      old.hot != hot ||
      old.cool != cool;
}

/// Ударная волна из центра окна: кольцо 20 px → 190 vmax, кромка
/// 3 → 0 px, `rgb(glow-hot/.9)` гаснет до нуля. В прототипе волна брала
/// радиус из потолка и при 8 px расходилась скруглённым квадратом.
class _ShockPainter extends CustomPainter {
  _ShockPainter({required this.shock, required this.color})
    : super(repaint: shock);

  final ValueListenable<double?> shock;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final e = shock.value;
    if (e == null || e >= 1) return;
    final diameter = 20 + (1.9 * size.longestSide - 20) * e;
    final width = 3 * (1 - e);
    if (width <= 0) return;
    // box-sizing: border-box — кромка лежит внутри диаметра
    canvas.drawCircle(
      size.center(Offset.zero),
      diameter / 2 - width / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color.withValues(alpha: .9 * (1 - e)),
    );
  }

  @override
  bool shouldRepaint(_ShockPainter old) =>
      old.shock != shock || old.color != color;
}

/// Полоса `.l-bar`: дорожка белого 10 %, заливка `hot-1 → hot-2 → #fff`
/// по своей длине и свечение 18 px, обрезанное дорожкой.
class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.progress,
    required this.hot1,
    required this.hot2,
    required this.radius,
  }) : super(repaint: progress);

  final ValueListenable<double> progress;
  final Color hot1;
  final Color hot2;

  /// Потолок радиуса панелей; на полосе в 2 px браузер режет его до 1.
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final track = Offset.zero & size;
    canvas
      ..save()
      ..clipRRect(
        RRect.fromRectAndRadius(
          track,
          Radius.circular(math.min(radius, size.height / 2)),
        ),
      )
      ..drawRect(
        track,
        Paint()..color = const Color.fromRGBO(255, 255, 255, .1),
      );
    final p = progress.value.clamp(0.0, 1.0);
    if (p > 0) {
      final fill = Rect.fromLTWH(0, 0, size.width * p, size.height);
      canvas
        ..drawRect(
          fill,
          Paint()
            ..color = hot1.withValues(alpha: .9)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
        )
        ..drawRect(
          fill,
          Paint()
            ..shader = ui.Gradient.linear(
              fill.centerLeft,
              fill.centerRight,
              [hot1, hot2, const Color(0xFFFFFFFF)],
              const [0, .5, 1],
            ),
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.progress != progress ||
      old.hot1 != hot1 ||
      old.hot2 != hot2 ||
      old.radius != radius;
}
