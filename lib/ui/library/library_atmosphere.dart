import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme.dart';
import 'particle_field.dart';

/// Одна ограниченная симуляция и один слой перерисовки. Сетка обложек —
/// удерживаемый ребёнок: ни движение мыши, ни кадр анимации её не трогают,
/// иначе каждый кадр перестраивал бы всю библиотеку.
class LibraryAtmosphere extends StatefulWidget {
  const LibraryAtmosphere({
    super.key,
    required this.enabled,
    this.particlesEnabled = true,
    this.ambientEnabled = true,
    required this.targetKey,
    required this.child,
  });

  final bool enabled;
  final bool particlesEnabled, ambientEnabled;
  final GlobalKey? Function() targetKey;
  final Widget child;

  @override
  State<LibraryAtmosphere> createState() => LibraryAtmosphereState();
}

class LibraryAtmosphereState extends State<LibraryAtmosphere>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final field = ParticleField();
  Rect? targetRect;
  Object? targetIdentity;
  final _repaint = _PaintSignal();
  final _viewport = GlobalKey();
  late final Ticker _ticker = createTicker(_tick);
  Duration? _previous;
  bool _foreground = true;
  bool _motion = false;
  double _ambientTime = 0;
  bool get isAnimating => _ticker.isActive && !_ticker.muted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(LibraryAtmosphere oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  void _syncMotion() {
    _motion =
        widget.enabled &&
        (widget.particlesEnabled ||
            (widget.ambientEnabled && !context.colors.isDark)) &&
        !MediaQuery.disableAnimationsOf(context) &&
        (ModalRoute.isCurrentOf(context) ?? true) &&
        TickerMode.valuesOf(context).enabled &&
        _foreground;
    if (_motion && !_ticker.isActive) {
      _previous = null;
      _ticker.start();
    } else if (!_motion && _ticker.isActive) {
      _ticker.stop();
      _previous = null;
      field.pointer = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  void _tick(Duration elapsed) {
    if (_previous != null && (elapsed - _previous!).inMicroseconds < 16000) {
      return;
    }
    final box = _viewport.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    if (widget.particlesEnabled) field.resize(box.size);
    final key = widget.targetKey();
    final tile = key?.currentContext?.findRenderObject();
    Rect? rect;
    if (tile is RenderBox && tile.attached && tile.hasSize) {
      final offset = box.globalToLocal(tile.localToGlobal(Offset.zero));
      final candidate = offset & tile.size;
      if (candidate.overlaps(Offset.zero & box.size)) rect = candidate;
    }
    targetRect = rect;
    targetIdentity = rect == null ? null : key;
    final dt = _previous == null
        ? 1 / 60
        : (elapsed - _previous!).inMicroseconds /
              Duration.microsecondsPerSecond;
    _previous = elapsed;
    _ambientTime += dt.clamp(0.0, 1 / 30);
    if (widget.particlesEnabled) {
      field.card = rect?.inflate(8);
      field.step(dt);
    }
    _repaint.repaint();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MouseRegion(
      onHover: (event) {
        if (_motion && widget.particlesEnabled) {
          field.pointer = event.localPosition;
        }
      },
      onExit: (_) => field.pointer = null,
      child: ClipRect(
        key: _viewport,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Уменьшенная анимация оставляет точки неподвижными, а явное
            // выключение убирает их вовсе: остановленная симуляция всё ещё
            // рисует, и «выключено» должно значить «не видно».
            if (widget.enabled && widget.particlesEnabled) {
              field.resize(constraints.biggest);
            } else {
              field.particles.clear();
              field.size = Size.zero;
              field.pointer = null;
              field.card = null;
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                if (widget.enabled)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          key: const ValueKey('library-atmosphere-paint'),
                          painter: _AtmospherePainter(
                            field: field,
                            colors: colors,
                            particlesEnabled: widget.particlesEnabled,
                            ambientEnabled: widget.ambientEnabled,
                            ambientTime: () => _ambientTime,
                            animated:
                                widget.enabled &&
                                !MediaQuery.disableAnimationsOf(context),
                            repaint: _repaint,
                          ),
                        ),
                      ),
                    ),
                  ),
                RepaintBoundary(child: widget.child),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PaintSignal extends ChangeNotifier {
  void repaint() => notifyListeners();
}

class _AtmospherePainter extends CustomPainter {
  _AtmospherePainter({
    required this.field,
    required this.colors,
    required this.animated,
    required this.particlesEnabled,
    required this.ambientEnabled,
    required this.ambientTime,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final ParticleField field;
  final EvaporatePalette colors;
  final bool animated;
  final bool particlesEnabled, ambientEnabled;
  final double Function() ambientTime;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final time = animated ? ambientTime() : 0.0;
    // Медленные малоконтрастные перламутровые разводы по слоновой кости.
    // Контраст низкий намеренно: под текстом фон не должен мигать.
    if (ambientEnabled && !colors.isDark) {
      for (var i = 0; i < 4; i++) {
        final center = Offset(
          size.width * (0.5 + 0.45 * math.sin(time * 0.13 + i * 1.8)),
          size.height * (0.5 + 0.43 * math.cos(time * 0.11 + i * 2.1)),
        );
        final radius = size.longestSide * 0.65;
        final paint = Paint()
          ..shader = RadialGradient(
            colors: [
              libraryInkColors[i].withValues(alpha: 0.075),
              libraryInkColors[i].withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius));
        canvas.drawRect(bounds, paint);
      }
    }
    if (!particlesEnabled) return;
    final dot = Paint();
    for (final particle in field.particles) {
      if (!animated && particle.life >= 0) continue;
      final color = particleColor(
        isDark: colors.isDark,
        phase: particle.phase,
        glow: animated ? particle.glow : 0,
      );
      final fade = particle.life < 0
          ? 1.0
          : (particle.life / 0.35).clamp(0.0, 1.0);
      // Чёткие точки постоянного размера, без слоя размытия и свечения:
      // они и дешевле, и не превращают фон в туман.
      dot.color = color.withValues(alpha: fade);
      canvas.drawCircle(particle.position, InkParticle.radius, dot);
    }
  }

  @override
  bool shouldRepaint(_AtmospherePainter oldDelegate) =>
      oldDelegate.colors != colors ||
      oldDelegate.animated != animated ||
      oldDelegate.particlesEnabled != particlesEnabled ||
      oldDelegate.ambientEnabled != ambientEnabled;
}
