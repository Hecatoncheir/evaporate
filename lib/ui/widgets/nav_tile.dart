import 'package:flutter/material.dart';

import '../theme.dart';

/// Фокусируемая плитка: работает и мышью, и с клавиатуры, и с геймпада.
///
/// Обычный `InkWell` фокус принимает, но никак его не показывает — при
/// управлении без мыши это делает интерфейс непроходимым, поэтому рамка
/// фокуса здесь обязательная часть.
class NavTile extends StatefulWidget {
  const NavTile({
    super.key,
    required this.child,
    required this.onTap,
    this.selected = false,
    this.autofocus = false,
    this.focusNode,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    this.margin = const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    this.borderRadius = 8,
  });

  final Widget child;
  final VoidCallback onTap;

  /// Выбранный элемент (то, что открыто справа) — не то же самое, что фокус.
  final bool selected;
  final bool autofocus;
  final FocusNode? focusNode;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double borderRadius;

  @override
  State<NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<NavTile> {
  bool _focused = false;

  void _onFocusChange(bool value) {
    if (mounted) setState(() => _focused = value);
    if (!value) return;
    // Фокус мог уехать за пределы видимой области списка.
    final context = this.context;
    if (context.mounted) {
      Scrollable.ensureVisible(
        context,
        alignment: 0.1,
        duration: const Duration(milliseconds: 120),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final background = widget.selected
        ? EvaporateTheme.surfaceHigh
        : Colors.transparent;

    return Padding(
      padding: widget.margin,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: InkWell(
          onTap: widget.onTap,
          autofocus: widget.autofocus,
          focusNode: widget.focusNode,
          onFocusChange: _onFocusChange,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: widget.padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: _focused ? EvaporateTheme.primary : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
