import 'package:flutter/widgets.dart';

/// Строит своё содержимое заново, когда над ним появляется или уходит
/// курсор.
///
/// Флаг `_hovered` с `MouseRegion` вокруг был выписан в четырёх `State`, и
/// каждый заводил `StatefulWidget` только ради него. Наведение — не
/// состояние виджета, а обстоятельство, в котором его рисуют.
///
/// Сборщик получает `hovered` и [child] — часть, которой наведение не
/// касается и которую незачем перестраивать на каждом входе курсора.
class HoverBuilder extends StatefulWidget {
  const HoverBuilder({super.key, required this.builder, this.child});

  final ValueWidgetBuilder<bool> builder;
  final Widget? child;

  @override
  State<HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<HoverBuilder> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.builder(context, _hovered, widget.child),
    );
  }
}
