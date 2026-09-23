import 'package:flutter/material.dart';

import '../theme.dart';

/// Фокусируемая оправа обложки: работает и мышью, и с клавиатуры, и с
/// геймпада.
///
/// Обычный `InkWell` фокус принимает, но никак его не показывает — при
/// управлении без мыши это делает интерфейс непроходимым. Фокус обозначают
/// рамка и рост обложки; foil-перелив добавляет плитка сверху.
class NavTile extends StatefulWidget {
  const NavTile({
    super.key,
    required this.child,
    required this.onTap,
    this.autofocus = false,
    this.focusNode,
    this.onFocusChange,
    this.showFocusBorder = true,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool showFocusBorder;

  /// Фокус переехал сюда или ушёл отсюда. Нужен там, где выбор следует за
  /// фокусом, а не за нажатием.
  final ValueChanged<bool>? onFocusChange;

  /// Насколько обложка подрастает под фокусом. В сетке рост заметнее
  /// рамки: соседи расступаются, и видно, где ты, даже боковым зрением.
  static const _focusedScale = 1.06;

  static const _borderWidth = 2.5;

  @override
  State<NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<NavTile> {
  bool _focused = false;

  void _onFocusChange(bool value) {
    if (mounted) setState(() => _focused = value);
    widget.onFocusChange?.call(value);
    if (!value) return;
    // Фокус мог уехать за пределы видимой области списка.
    final context = this.context;
    if (context.mounted) {
      Scrollable.ensureVisible(
        context,
        alignment: 0.1,
        duration: context.motion.instant,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(EvaporateTheme.radiusControl);
    return Material(
      // Подсветку рисует контейнер ниже: на Material она переключалась бы
      // рывком, тогда как рамка фокуса рядом уже плавная.
      color: AppColors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: widget.onTap,
        autofocus: widget.autofocus,
        focusNode: widget.focusNode,
        onFocusChange: _onFocusChange,
        borderRadius: radius,
        child: AnimatedScale(
          scale: _focused ? NavTile._focusedScale : 1,
          duration: context.motion.instant,
          curve: EvaporateMotion.ease,
          child: AnimatedContainer(
            duration: context.motion.instant,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: widget.showFocusBorder
                  ? Border.all(
                      color: _focused
                          ? context.colors.selection
                          : AppColors.transparent,
                      width: NavTile._borderWidth,
                    )
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
