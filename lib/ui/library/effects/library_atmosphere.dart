import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/decoration_clock.dart';
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
    with SingleTickerProviderStateMixin, DecorationClock {
  final field = ParticleField();
  Rect? targetRect;
  Object? targetIdentity;
  final _repaint = _PaintSignal();
  final _viewport = GlobalKey();
  double _ambientTime = 0;

  @override
  bool get wantsFrames =>
      widget.enabled &&
      (widget.particlesEnabled ||
          (widget.ambientEnabled && EffectsPalette.of(context).ambientWash));

  @override
  void syncClock() {
    super.syncClock();
    // Стоящим частицам следить за курсором незачем.
    if (!clockRunning) field.pointer = null;
  }

  @override
  void onFrame(double dt) {
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
    _ambientTime += dt;
    if (widget.particlesEnabled) {
      field.card = rect?.inflate(8);
      field.step(dt);
    }
    _repaint.repaint();
  }

  @override
  void dispose() {
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        if (clockRunning && widget.particlesEnabled) {
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
                            effects: EffectsPalette.of(context),
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
    required this.effects,
    required this.animated,
    required this.particlesEnabled,
    required this.ambientEnabled,
    required this.ambientTime,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final ParticleField field;
  final EffectsPalette effects;
  final bool animated;
  final bool particlesEnabled, ambientEnabled;
  final double Function() ambientTime;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final time = animated ? ambientTime() : 0.0;
    // Медленные малоконтрастные перламутровые разводы по слоновой кости.
    // Контраст низкий намеренно: под текстом фон не должен мигать.
    if (ambientEnabled && effects.ambientWash) {
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
      final color = effects.particle(
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
      oldDelegate.effects != effects ||
      oldDelegate.animated != animated ||
      oldDelegate.particlesEnabled != particlesEnabled ||
      oldDelegate.ambientEnabled != ambientEnabled;
}
