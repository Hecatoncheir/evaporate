import 'package:flutter/material.dart';

import '../../models/game.dart';
import '../labels.dart';
import '../theme.dart';
import 'spatial_surface.dart';
import '../../l10n/app_localizations.dart';

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
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = widget.onPressed != null;
    final radius = BorderRadius.circular(EvaporateTheme.radiusControl);

    // Ход клавиши: в дневной схеме он равен толщине торца, иначе кнопка
    // проваливалась бы сквозь него.
    final travel = colors.depth.a == 0 ? 1.0 : 3.0;
    final sunk = _pressed && enabled;
    final lit = _hovered && enabled;

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
            ),
            child: Material(
              color: AppColors.transparent,
              child: InkWell(
                onTap: widget.onPressed,
                onHighlightChanged: (value) => setState(() => _pressed = value),
                borderRadius: radius,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 112,
                    minHeight: 48,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _face(colors),
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
  }) => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        // Блик по верхней кромке. Днём его почти нет: плоский
        // цвет — часть замысла, а не упущение.
        Color.lerp(
          colors.primaryFill,
          AppColors.foilHighlight,
          colors.isDark ? 0.16 : 0.04,
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
        color: colors.isDark
            ? colors.glow.withValues(alpha: lit ? 0.34 : 0.18)
            : colors.shadow,
        blurRadius: lit ? 26 : 14,
        offset: Offset(0, sunk ? 2 : 6),
      ),
    ],
  );

  /// Надпись на клавише: значок и слово.
  Widget _face(EvaporatePalette colors) => Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(widget.icon, size: 18, color: colors.onPrimary),
      const SizedBox(width: 8),
      Text(
        widget.label,
        style: TextStyle(
          color: colors.onPrimary,
          fontFamily: EvaporateTheme.displayFontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    ],
  );
}

/// Небольшая цветная метка статуса — используется в списке и в карточке игры.
/// Мелкая клавиша со значком — пауза, отмена, удаление из очереди.
///
/// Голый `IconButton` на плотной подложке карточки терялся: значок в два
/// волоска служебного цвета читается как украшение, а не как орган
/// управления, и найти его глазами на графике загрузки было нечем.
/// Подложка с кантом — тот же приём, что у [StatusChip]: цвет в четырнадцать
/// процентов под содержимым в полную силу.
///
/// Область нажатия остаётся прежней. Это не придирка: [danger] у отмены
/// выбрасывает скачанное, и делать такую клавишу **крупнее** значило бы
/// покупать заметность ценой случайных попаданий.
class IconAction extends StatelessWidget {
  const IconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Действие теряет сделанное — отмена загрузки выбрасывает скачанное.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? context.colors.danger : context.colors.primary;
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withValues(alpha: 0.14),
        side: BorderSide(color: color.withValues(alpha: 0.34)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EvaporateTheme.radiusControl),
        ),
        minimumSize: const Size(30, 30),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.compact = false});

  final GameStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = gameStatusLabel(L.of(context), status);
    final color = switch (status) {
      GameStatus.notInstalled => context.colors.textSecondary,
      GameStatus.downloading => context.colors.primary,
      GameStatus.paused => context.colors.warning,
      GameStatus.installed => context.colors.accent,
      GameStatus.running => context.colors.accent,
      GameStatus.error => context.colors.danger,
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(EvaporateTheme.radiusChip),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassSurface(
        radius: EvaporateTheme.radiusPanel,
        opacity: context.colors.isDark ? 0.62 : 0.74,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: context.colors.textSecondary),
                  const SizedBox(width: 8),
                ],

                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: context.colors.accent),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  description!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Пара «подпись — значение» для блоков с информацией.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.monospace = false,
    this.trailing,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool monospace;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 13,
                color: valueColor,
                fontFamily: monospace ? EvaporateTheme.monoFontFamily : null,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(error.toString()),
      backgroundColor: context.colors.danger.withValues(alpha: 0.9),
    ),
  );
}

void showInfo(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  // Значение по умолчанию должно быть константой, а перевод ею быть не
  // может: подставляем его внутри.
  String? confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message, style: const TextStyle(height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(L.of(context).cancel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: context.colors.danger)
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel ?? L.of(context).confirm),
        ),
      ],
    ),
  );
  return result ?? false;
}
