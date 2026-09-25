import 'package:flutter/material.dart';

import '../theme.dart';

/// Главное действие лаунчера: цветная клавиша с настоящим ходом.
///
/// Тонов у неё два ([LauncherTone]): запуск горит огнём главного действия,
/// загрузка — холодным цветом данных. Геометрия совпадает с соседними
/// обычными кнопками, поэтому ряд действий выглядит единым, а цвет остаётся
/// единственным на весь экран криком.
/// Клавиша стоит на своём тёмном торце и при нажатии в него проваливается
/// — это и есть разница между экраном и железкой. Схемы расходятся не
/// одним оттенком, а материалом (`LauncherButtonTheme`): ночью заливка —
/// переход огня со светом изнутри, и клавиша светится своим цветом; днём
/// заливка плоская, а светлый корпус не светится.
class LauncherActionButton extends StatefulWidget {
  const LauncherActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.tone,
    required this.onPressed,
  });

  final String label;
  final IconData icon;

  /// Запускает клавиша игру или качает её: у загрузки своя, холодная
  /// заливка.
  final LauncherTone tone;
  final VoidCallback? onPressed;

  @override
  State<LauncherActionButton> createState() => _LauncherActionButtonState();
}

class _LauncherActionButtonState extends State<LauncherActionButton> {
  bool _hovered = false;
  bool _pressed = false;

  /// В фокусе — с клавиатуры или геймпада. Прежде у главной клавиши не
  /// было видно ничего, кроме бледной заливки поверх золота: дошедший до
  /// неё стрелками не знал, что он на ней.
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final look = LauncherButtonTheme.of(context);
    final enabled = widget.onPressed != null;
    final radius = BorderRadius.circular(EvaporateTheme.radiusControl);

    // Ход клавиши равен толщине торца, иначе кнопка проваливалась бы
    // сквозь него.
    final depth = look.depthOf(widget.tone, colors);
    final travel = depth.a == 0 ? 1.0 : 3.0;
    final sunk = _pressed && enabled;
    // Свет изнутри лежит на материале под следом нажатия: иначе вспышка
    // от нажатия гасла бы под ним.
    final core = BoxDecoration(gradient: look.core, borderRadius: radius);

    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : EvaporateAlpha.disabled,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: context.motion.fast,
            curve: EvaporateMotion.ease,
            transform: Matrix4.translationValues(0, sunk ? travel : 0, 0),
            decoration: _decoration(
              colors,
              look,
              radius: radius,
              depth: depth,
              travel: travel,
              sunk: sunk,
              lit: (_hovered || _focused) && enabled,
              focused: _focused && enabled,
            ),
            child: Material(
              color: AppColors.transparent,
              child: Ink(
                decoration: core,
                child: InkWell(
                  onTap: widget.onPressed,
                  onHighlightChanged: (value) =>
                      setState(() => _pressed = value),
                  onFocusChange: (value) => setState(() => _focused = value),
                  borderRadius: radius,
                  child: _Face(
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
    );
  }

  /// Материал клавиши: заливка своего тона, тёмный торец под ней и ореол
  /// вокруг.
  BoxDecoration _decoration(
    EvaporatePalette colors,
    LauncherButtonTheme look, {
    required BorderRadius radius,
    required Color depth,
    required double travel,
    required bool sunk,
    required bool lit,
    required bool focused,
  }) => BoxDecoration(
    // Кант того же цвета выбора, что у плиток и клавиш обоймы: фокус
    // выглядит одинаково везде, куда до него дошли.
    border: focused ? Border.all(color: colors.selection, width: 2) : null,
    gradient: look.fillOf(widget.tone),
    borderRadius: radius,
    boxShadow: [
      // Торец, на котором клавиша стоит.
      if (depth.a > 0)
        BoxShadow(
          color: depth,
          offset: Offset(0, sunk ? 1 : travel),
          spreadRadius: -0.5,
        ),
      BoxShadow(
        // Ореол есть не у каждого материала: у светлого корпуса его нет,
        // и клавиша стоит на обычной тени.
        color: look.haloLit > 0
            ? look
                  .haloOf(widget.tone, colors)
                  .withValues(alpha: lit ? look.haloLit : look.haloRest)
            : colors.shadow,
        blurRadius: lit ? 26 : 14,
        offset: Offset(0, sunk ? 2 : 6),
      ),
    ],
  );
}

/// Лицо главной клавиши: значок и слово на поле клавиши.
///
/// Размер — как у соседних обычных кнопок, чтобы ряд действий стоял ровно.
class _Face extends StatelessWidget {
  const _Face({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 112, minHeight: 48),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: EvaporateSpacing.panel),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: EvaporateIconSize.panel, color: color),
          const SizedBox(width: EvaporateSpacing.gap),
          Text(label, style: context.text.keycap.copyWith(color: color)),
        ],
      ),
    ),
  );
}
