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
    if (value && mounted) _reveal();
  }

  /// Выводит плитку в видимое — подросшей под фокусом и ровно настолько,
  /// насколько нужно; видную целиком страницу не двигает.
  ///
  /// Сетка — часть одной прокрутки со всей страницей
  /// (`docs/decisions/0014`), и прежняя доля 0.1 от каждой фокусировки
  /// уносила под полосу крупный кадр с клавишей «Играть» даже с первого
  /// ряда: пока прокручивалась одна сетка, первому ряду мешал упор в ноль.
  /// Рост считаем потому, что обход стрелками подводит плитку вплотную к
  /// краю, и без него низ обложки с рамкой оставался под строкой подсказок.
  /// Край видимого — между полосами каркаса: окно прокрутки отвечает
  /// «куда мотать» с их учётом.
  void _reveal() {
    final tile = context.findRenderObject();
    if (tile is! RenderBox) return;
    tile.showOnScreen(
      rect: Rect.fromCenter(
        center: tile.size.center(Offset.zero),
        width: tile.size.width * NavTile._focusedScale,
        height: tile.size.height * NavTile._focusedScale,
      ),
      duration: context.motion.instant,
      curve: EvaporateMotion.ease,
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(EvaporateTheme.radiusPanel);
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
