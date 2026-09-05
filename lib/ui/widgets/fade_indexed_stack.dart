import 'package:flutter/material.dart';

/// [IndexedStack], который меняет разделы затуханием, а не рывком.
///
/// Обычный `AnimatedSwitcher` здесь не подходит: он выбрасывает прежнего
/// ребёнка и вместе с ним всё его состояние — положение прокрутки, введённый
/// текст, поднятый фокус. Раздел, куда вернулись, должен выглядеть так же,
/// как его оставили, поэтому дети живут всегда, а меняется только прозрачность.
class FadeIndexedStack extends StatefulWidget {
  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 150),
    this.enabled = true,
  });

  final int index;
  final bool enabled;
  final List<Widget> children;

  /// Коротко по замыслу: разделы переключают и с геймпада, где любая
  /// задержка читается как подтормаживание.
  final Duration duration;

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
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
    if (!widget.enabled || MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      child: IndexedStack(
        index: widget.index,
        children: [
          for (var i = 0; i < widget.children.length; i++)
            TickerMode(enabled: i == widget.index, child: widget.children[i]),
        ],
      ),
    );
  }
}
