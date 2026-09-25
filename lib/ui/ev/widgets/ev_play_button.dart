import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../sound/ev_sound.dart';
import '../sound/voices.dart';
import 'ev_icon.dart';

/// Кнопка запуска — единственный насыщенный объект на экране.
///
/// Собрана из пяти слоёв, имитирующих подповерхностное рассеивание: свет
/// рождается внутри оболочки, а не лежит на ней.
///
/// * −1 — ядро: радиальный белый в янтарь, размытие 6, дышит 3.6 с;
/// * 0 — оболочка: линейный градиент 115°;
/// * внутрь — светлая кромка сверху и тёплая тень снизу;
/// * +1 — спекулярный блик, проходит за 1.05 с при наведении;
/// * наружу — свечение на фон.
///
/// Нажатие не запускает игру: кнопку нужно **удерживать** 620 мс. Это защита
/// от случайного старта и заодно момент, ради которого всё остальное затевалось.
///
/// С клавиатуры — так же, как в прототипе: `Пробел` или `Enter` держат заряд,
/// отпущенная клавиша сбрасывает его. Рамка фокуса — только в режиме
/// клавиатуры, как у остальных кнопок.
class EvPlayButton extends StatefulWidget {
  const EvPlayButton({
    super.key,
    required this.onLaunch,
    this.label = 'Играть',
    this.icon = EvIcons.play,
    this.requireHold = true,
    this.height = 56,
    this.onCharge,
    this.caption,
    this.cool = false,
  });

  /// `null` — действия пока нет: кнопка выглядит так же, но не
  /// нажимается, не удерживается и фокус не получает.
  final VoidCallback? onLaunch;

  final String label;
  final String icon;

  /// Выключается в настройках — тогда кнопка срабатывает по нажатию.
  final bool requireHold;

  final double height;

  /// Заряд 0…1 на каждом кадре удержания и сброса — для тех, кто греется
  /// вместе с кнопкой: герой дрожит тепловым маревом.
  final ValueChanged<double>? onCharge;

  /// Приписка мелким моноширинным справа от подписи. По умолчанию
  /// «УДЕРЖАТЬ», когда кнопку нужно держать; в карточке игры там стоит
  /// размер загрузки или её процент.
  final String? caption;

  /// Холодная заливка: так помечена загрузка — данные, а не запуск.
  final bool cool;

  @override
  State<EvPlayButton> createState() => _EvPlayButtonState();
}

class _EvPlayButtonState extends State<EvPlayButton>
    with TickerProviderStateMixin {
  // Удержание — защита, а не анимация: при «уменьшить движение» обычный
  // контроллер шёл бы в двадцать раз быстрее, и 620 мс стали бы 31.
  late final AnimationController _hold =
      AnimationController(
          vsync: this,
          duration: EvMotion.hold,
          reverseDuration: const Duration(milliseconds: 160),
          animationBehavior: AnimationBehavior.preserve,
        )
        ..addStatusListener(_onHold)
        ..addListener(() => widget.onCharge?.call(_hold.value));

  late final FocusNode _focus = FocusNode(
    debugLabel: 'EvPlayButton',
    onKeyEvent: _onKey,
  );
  bool _ring = false;

  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: EvMotion.breathe,
  );

  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  );

  bool _hover = false;
  bool _down = false;

  /// Голос удержания, пока его держат.
  EvHoldVoice? _voice;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Дыхание ядра — единственная бесконечная анимация в системе. При
    // «уменьшить анимацию» она останавливается: иначе окно перерисовывается
    // вечно, а тесты не досчитываются до покоя.
    final reduced =
        MediaQuery.disableAnimationsOf(context) || widget.onLaunch == null;
    if (reduced) {
      _breathe.stop();
      _breathe.value = 0.5;
    } else if (!_breathe.isAnimating) {
      _breathe.repeat(reverse: true);
    }
  }

  void _onHold(AnimationStatus s) {
    if (s == AnimationStatus.completed) {
      _voice?.strike();
      _voice = null;
      _hold.value = 0;
      setState(() => _down = false);
      widget.onLaunch?.call();
    }
  }

  @override
  void dispose() {
    _voice?.release();
    _hold.dispose();
    _breathe.dispose();
    _sweep.dispose();
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.space &&
        key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    // Повтор клавиши не перезапускает заряд, а отпускание сбрасывает его.
    if (event is KeyDownEvent && !_down) _press();
    if (event is KeyUpEvent) _release();
    return KeyEventResult.handled;
  }

  void _press() {
    final launch = widget.onLaunch;
    if (launch == null) return;
    final sound = EvSoundScope.maybeOf(context);
    if (!widget.requireHold) {
      sound?.play(EvVoice.tap);
      launch();
      return;
    }
    setState(() => _down = true);
    _voice = sound?.hold();
    _hold.forward();
  }

  void _release() {
    if (!_down) return;
    setState(() => _down = false);
    _voice?.release();
    _voice = null;
    _hold.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final r = ev.radii.pill.clamp(0.0, widget.height / 2);

    return FocusableActionDetector(
      enabled: widget.onLaunch != null,
      focusNode: _focus,
      mouseCursor: SystemMouseCursors.click,
      onShowFocusHighlight: (value) => setState(() => _ring = value),
      onShowHoverHighlight: (value) {
        setState(() => _hover = value);
        if (value) {
          _sweep.forward(from: 0);
        } else {
          _release();
        }
      },
      child: Listener(
        onPointerDown: (_) => _press(),
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: Semantics(
          button: true,
          label: widget.requireHold && widget.onLaunch != null
              ? '${widget.label}. Удерживайте, чтобы запустить'
              : widget.label,
          child: AnimatedBuilder(
            animation: Listenable.merge([_hold, _breathe, _sweep]),
            builder: (context, _) {
              final lift = _hover && !_down ? -2.0 : 0.0;
              return Transform.translate(
                offset: Offset(0, lift),
                child: CustomPaint(
                  foregroundPainter: _ChargeRingPainter(
                    progress: _hold.value,
                    color: c.hot2,
                    radius: r,
                    inset: -11,
                    focusRing: _ring,
                  ),
                  child: Container(
                    height: widget.height,
                    padding: const EdgeInsets.only(left: 22, right: 26),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(r),
                      gradient: widget.cool ? _coolFill(c) : c.playFill,
                      boxShadow: [
                        BoxShadow(
                          color: (widget.cool ? c.cool : c.hot1).withValues(
                            alpha: _hover ? 0.55 : 0.42,
                          ),
                          blurRadius: _hover ? 46 : 34,
                          offset: Offset(0, _hover ? 16 : 10),
                        ),
                      ],
                      border: Border.all(
                        color: (widget.cool ? c.cool : c.hot1).withValues(
                          alpha: _hover ? 0.5 : 0.35,
                        ),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(r),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // −1 · ядро: свет изнутри оболочки
                          Positioned.fill(child: _core(c)),
                          // внутрь · светлая кромка сверху
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 1,
                            child: ColoredBox(
                              color: c.ink.withValues(alpha: 0.55),
                            ),
                          ),
                          // +1 · спекулярный блик
                          if (_sweep.isAnimating)
                            Positioned.fill(child: _specular()),
                          _content(ev),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _core(EvColors c) {
    final t = Curves.easeInOut.transform(_breathe.value);
    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: Opacity(
        opacity: 0.75 + 0.25 * t,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.56, 0),
              radius: 0.9 + 0.05 * t,
              colors: [
                const Color(0xFFFFFFFF).withValues(alpha: 0.85),
                const Color(0xFFFFD278).withValues(alpha: 0.35),
                const Color(0x00000000),
              ],
              stops: const [0, 0.4, 0.72],
            ),
          ),
        ),
      ),
    );
  }

  Widget _specular() {
    final x = -0.9 + 2.2 * Curves.easeOut.transform(_sweep.value);
    return Transform(
      transform: Matrix4.skewX(-0.32),
      alignment: Alignment.center,
      child: FractionallySizedBox(
        widthFactor: 0.38,
        alignment: Alignment(x, 0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0x00FFFFFF),
                const Color(0xFFFFFFFF).withValues(alpha: 0.55),
                const Color(0x00FFFFFF),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// `.pbtn.cool` — заливка загрузки: цвет данных, а не запуска.
  static LinearGradient _coolFill(EvColors c) => LinearGradient(
    begin: const Alignment(-0.9, -0.6),
    end: const Alignment(0.9, 0.6),
    colors: [const Color(0xFFA9F2FF), c.cool, const Color(0xFF1B6F8A)],
    stops: const [0.0, 0.58, 1.0],
  );

  Widget _content(EvTheme ev) {
    final onFill = widget.cool
        ? const Color(0xFF031318)
        : const Color(0xFF170800);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        EvIcon(widget.icon, size: 19, color: onFill),
        const SizedBox(width: 13),
        Text(
          widget.label,
          style: ev.text.ui(
            ev.text.title,
            weight: FontWeight.w600,
            color: onFill,
          ),
        ),
        if (widget.caption != null || widget.requireHold) ...[
          const SizedBox(width: 13),
          Text(
            widget.caption ?? 'УДЕРЖАТЬ',
            style: ev.text.data.copyWith(
              color: onFill.withValues(alpha: 0.62),
              fontSize: 10,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

/// Кольцо заряда обходит кнопку за 620 мс. Рисуется поверх, с отступом
/// наружу, чтобы не спорить с кромкой. Здесь же рамка фокуса: 2 px `hot2`
/// с отступом 3 px, как `:focus-visible` в прототипе.
class _ChargeRingPainter extends CustomPainter {
  _ChargeRingPainter({
    required this.progress,
    required this.color,
    required this.radius,
    required this.inset,
    required this.focusRing,
  });

  final double progress;
  final Color color;
  final double radius;
  final double inset;
  final bool focusRing;

  @override
  void paint(Canvas canvas, Size size) {
    if (focusRing) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).inflate(4),
          Radius.circular(radius + 4),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color,
      );
    }
    if (progress <= 0) return;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height).deflate(inset);
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(radius - inset),
    );
    final path = Path()..addRRect(rrect);

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final m = metrics.first;
    final drawn = m.extractPath(0, m.length * progress.clamp(0.0, 1.0));

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = color
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.solid, 3);
    canvas.drawPath(drawn, paint);
  }

  @override
  bool shouldRepaint(_ChargeRingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.radius != radius ||
      old.focusRing != focusRing;
}
