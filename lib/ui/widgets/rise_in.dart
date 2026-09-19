import 'package:flutter/material.dart';

import '../theme.dart';

/// Появление снизу вверх с задержкой по номеру в ряду.
///
/// Полка, всходящая очередью, читается как один жест; та же полка,
/// возникающая разом, — как подмена картинки. Разница в полсекунды, а
/// ощущение от приложения разное.
///
/// Задержка сделана **интервалом внутри одной анимации**, а не таймером:
/// таймер, не успевший сработать, валит виджет-тесты, а незакрытый —
/// переживает виджет и дёргает мёртвое состояние.
class RiseIn extends StatefulWidget {
  const RiseIn({
    super.key,
    required this.delay,
    required this.child,
    this.enabled = true,
    this.offset = 18,
  });

  final Duration delay;
  final Widget child;
  final bool enabled;

  /// Насколько ниже своего места элемент начинает путь.
  final double offset;

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration.zero,
  );
  Animation<double> _curve = const AlwaysStoppedAnimation(1);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _start();
  }

  void _start() {
    // Один раз: пересборка от смены темы или размера окна не должна
    // заново поднимать уже стоящую на месте плитку.
    if (_controller.duration != Duration.zero) return;

    final motion = context.motion;
    final total = widget.delay + motion.base;
    if (!widget.enabled || total == Duration.zero) {
      _controller.duration = const Duration(milliseconds: 1);
      _controller.value = 1;
      return;
    }
    _controller.duration = total;
    final head = widget.delay.inMicroseconds / total.inMicroseconds;
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(head, 1, curve: EvaporateMotion.enter),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    // Кривая вешает слушателя на контроллер — освобождаем её первой.
    final curve = _curve;
    if (curve is CurvedAnimation) curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _curve,
    child: widget.child,
    builder: (context, child) => Opacity(
      // Прозрачность догоняет смещение: иначе плитка проявляется уже на
      // своём месте, и движения не видно.
      opacity: Curves.easeOut.transform(_curve.value.clamp(0.0, 1.0)),
      child: Transform.translate(
        offset: Offset(0, widget.offset * (1 - _curve.value)),
        child: child,
      ),
    ),
  );
}
