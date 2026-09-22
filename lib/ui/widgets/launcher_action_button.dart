import 'package:flutter/material.dart';

import '../theme.dart';
import 'launcher_action_face.dart';

/// Главное действие лаунчера: клавиша фирменного цвета с настоящим ходом.
///
/// Геометрия совпадает с соседними обычными кнопками, поэтому ряд действий
/// выглядит единым, а цвет остаётся единственным на весь экран криком.
/// Схемы расходятся не оттенком, а материалом: ночью клавиша светится
/// золотом, днём стоит на своём тёмном торце и при нажатии в него
/// проваливается — это и есть разница между экраном и железкой.
class LauncherActionButton extends StatefulWidget {
  const LauncherActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  State<LauncherActionButton> createState() => _LauncherActionButtonState();
}

class _LauncherActionButtonState extends State<LauncherActionButton> {
  static const _facePadding = EdgeInsets.symmetric(
    horizontal: EvaporateSpacing.panel,
  );

  bool _hovered = false;
  bool _pressed = false;

  /// В фокусе — с клавиатуры или геймпада. Прежде у главной клавиши не
  /// было видно ничего, кроме бледной заливки поверх золота: дошедший до
  /// неё стрелками не знал, что он на ней.
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = widget.onPressed != null;
    final radius = BorderRadius.circular(EvaporateTheme.radiusControl);

    // Ход клавиши: в дневной схеме он равен толщине торца, иначе кнопка
    // проваливалась бы сквозь него.
    final travel = colors.depth.a == 0 ? 1.0 : 3.0;
    final sunk = _pressed && enabled;
    final lit = (_hovered || _focused) && enabled;

    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: context.motion.fast,
            curve: EvaporateMotion.ease,
            transform: Matrix4.translationValues(0, sunk ? travel : 0, 0),
            decoration: _decoration(
              colors,
              radius: radius,
              travel: travel,
              sunk: sunk,
              lit: lit,
              focused: _focused && enabled,
            ),
            child: Material(
              color: AppColors.transparent,
              child: InkWell(
                onTap: widget.onPressed,
                onHighlightChanged: (value) => setState(() => _pressed = value),
                onFocusChange: (value) => setState(() => _focused = value),
                borderRadius: radius,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 112,
                    minHeight: 48,
                  ),
                  child: Padding(
                    padding: _facePadding,
                    child: LauncherActionFace(
                      label: widget.label,
                      icon: widget.icon,
                      color: colors.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Материал клавиши: блик по верхней кромке, тёмный торец под ней и
  /// ореол вокруг.
  BoxDecoration _decoration(
    EvaporatePalette colors, {
    required BorderRadius radius,
    required double travel,
    required bool sunk,
    required bool lit,
    required bool focused,
  }) => BoxDecoration(
    // Кант того же цвета выбора, что у плиток и клавиш обоймы: фокус
    // выглядит одинаково везде, куда до него дошли.
    border: focused ? Border.all(color: colors.selection, width: 2) : null,
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        // Блик по верхней кромке. Днём его почти нет: плоский
        // цвет — часть замысла, а не упущение.
        Color.lerp(
          colors.primaryFill,
          AppColors.foilHighlight,
          HardwareSurfaceTheme.of(context).keySheen,
        )!,
        colors.primaryFill,
      ],
    ),
    borderRadius: radius,
    boxShadow: [
      // Торец, на котором клавиша стоит днём. Ночью его нет вовсе.
      if (colors.depth.a > 0)
        BoxShadow(
          color: colors.depth,
          offset: Offset(0, sunk ? 1 : travel),
          spreadRadius: -0.5,
        ),
      BoxShadow(
        // Ореол есть не у каждого материала: у светлого корпуса он
        // прозрачен, и клавиша стоит на обычной тени.
        color: colors.glow.a > 0
            ? colors.glow.withValues(alpha: lit ? 0.34 : 0.18)
            : colors.shadow,
        blurRadius: lit ? 26 : 14,
        offset: Offset(0, sunk ? 2 : 6),
      ),
    ],
  );
}
