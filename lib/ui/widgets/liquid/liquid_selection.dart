import 'package:flutter/material.dart';

import '../window_visibility.dart';
import 'liquid_geometry.dart';
import 'liquid_ink_scope.dart';
import 'liquid_painter.dart';

/// Слой выделения поверх удерживаемого содержимого: перетекает только
/// заливка, а подписи, обложки и области нажатия остаются на месте.
///
/// Перемычка нарисована векторными кривыми, а не размытием с отсечкой по
/// порогу: `BackdropFilter` увёл бы цвета темы, а их выверяли по контрасту.
class LiquidSelection extends StatefulWidget {
  const LiquidSelection({
    super.key,
    required this.targetKey,
    required this.color,
    required this.child,
    this.enabled = true,
    this.radius = 18,
    this.padding = EdgeInsets.zero,
    this.resting = true,
  });

  final GlobalKey? Function() targetKey;
  final Color color;
  final Widget child;
  final bool enabled, resting;
  final double radius;
  final EdgeInsets padding;

  @override
  State<LiquidSelection> createState() => LiquidSelectionState();
}

class LiquidSelectionState extends State<LiquidSelection>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _viewport = GlobalKey();
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    value: 1,
  );
  final _measured = ValueNotifier<int>(0);
  late final geometry = LiquidGeometry(
    viewport: _viewport,
    repaint: Listenable.merge([_animation, _measured]),
    travel: _animation,
  );
  GlobalKey? _identity;
  Rect? _from, _to;
  bool _queued = false;
  bool _allowed = false;

  bool get isAnimating => _animation.isAnimating;
  Rect? get targetRect => _to;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(LiquidSelection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    _allowed = widget.enabled && decorationMayRun(context);
    if (!_allowed) _animation.value = 1;
    _scheduleMeasure();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _sync();

  void _scheduleMeasure() {
    if (_queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (mounted) _measure();
    });
  }

  void _measure() {
    final identity = widget.targetKey();
    final rect = _rectOf(identity);
    if (rect == _to && identity == _identity) return;

    final previous = _to;
    final canTravel =
        _allowed &&
        previous != null &&
        rect != null &&
        identity != _identity &&
        _identity?.currentContext != null;
    _from = canTravel
        ? Rect.lerp(_from ?? previous, previous, _animation.value)
        : rect;
    _to = rect;
    _identity = identity;
    geometry.moveTo(from: _from, to: _to, radius: widget.radius);
    if (canTravel) {
      _animation.forward(from: 0);
    } else {
      // Перекладка, масштаб, прокрутка и исчезнувший пункт — не смена
      // выделения, и капле незачем ехать через весь экран.
      _animation.value = 1;
    }
    _measured.value++;
  }

  /// Где лежит цель — в координатах самой подложки.
  ///
  /// null, если цели нет, она ещё не измерена или уехала за пределы
  /// видимого: капле в этих случаях нечего обнимать.
  Rect? _rectOf(GlobalKey? identity) {
    final viewport = _viewport.currentContext?.findRenderObject();
    final target = identity?.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return null;
    if (target is! RenderBox || !target.attached || !target.hasSize) {
      return null;
    }

    final candidate = widget.padding.inflateRect(
      MatrixUtils.transformRect(
        target.getTransformTo(viewport),
        Offset.zero & target.size,
      ),
    );
    // Проверять на конечность нужно раньше, чем на пересечение: у предка
    // цели может оказаться вырожденное преобразование, и тогда перевод
    // в координаты подложки даёт NaN. `Rect.overlaps` такой прямоугольник
    // пропускает — сравнения с NaN всегда ложны, и ни один из его ранних
    // выходов не срабатывает, — а дальше NaN доезжает до `addRRect` и
    // роняет отрисовку кадра целиком.
    if (!candidate.isFinite) return null;
    return candidate.overlaps(Offset.zero & viewport.size) ? candidate : null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animation.dispose();
    _measured.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: (_) {
          _scheduleMeasure();
          return false;
        },
        child: NotificationListener<SizeChangedLayoutNotification>(
          onNotification: (_) {
            _scheduleMeasure();
            return false;
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              _scheduleMeasure();
              return Stack(
                key: _viewport,
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: LiquidPainter(
                            geometry: geometry,
                            color: widget.color,
                            resting: widget.resting,
                          ),
                        ),
                      ),
                    ),
                  ),
                  LiquidInkScope(
                    geometry: geometry,
                    child: SizeChangedLayoutNotifier(child: widget.child),
                  ),
                ],
              );
            },
          ),
        ),
      );
}
