import 'package:flutter/material.dart';

import '../theme.dart';

/// [IndexedStack], который меняет разделы проявлением, а не рывком.
///
/// Новый раздел проявляется и чуть всплывает снизу — на одну ступень
/// шкалы: так смена читается движением страницы, а не миганием.
///
/// Обычный `AnimatedSwitcher` здесь не подходит: он выбрасывает прежнего
/// ребёнка и вместе с ним всё его состояние — положение прокрутки, введённый
/// текст, поднятый фокус. Раздел, куда вернулись, должен выглядеть так же,
/// как его оставили, поэтому дети живут всегда, а меняются только
/// прозрачность и небольшой сдвиг.
class FadeIndexedStack extends StatefulWidget {
  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.enabled = true,
  });

  final int index;
  final bool enabled;
  final List<Widget> children;

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: 1,
  );

  /// Кривая заводится один раз: заведённая в `build`, она вешала бы на
  /// контроллер, живущий всю сессию, по слушателю на каждую пересборку.
  late final CurvedAnimation _opacity = CurvedAnimation(
    parent: _controller,
    curve: EvaporateMotion.ease,
  );

  @override
  void didUpdateWidget(FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (oldWidget.index != widget.index) {
      // Показываем новый раздел сразу, но проявляем его: перекрёстное
      // затухание потребовало бы держать оба видимыми, а они занимают
      // одно и то же место.
      _controller.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Коротко по замыслу: разделы переключают и с геймпада, где любая
    // задержка читается как подтормаживание.
    _controller.duration = context.motion.instant;
    if (!widget.enabled || MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _opacity.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: AnimatedBuilder(
        animation: _opacity,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, EvaporateSpacing.cluster * (1 - _opacity.value)),
          child: child,
        ),
        child: IndexedStack(
          index: widget.index,
          children: [
            for (var i = 0; i < widget.children.length; i++)
              TickerMode(enabled: i == widget.index, child: widget.children[i]),
          ],
        ),
      ),
    );
  }
}
