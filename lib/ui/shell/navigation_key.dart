import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/navigation/navigation_bloc.dart';
import '../../models/app_section.dart';
import '../theme.dart';
import '../widgets/liquid/liquid_selection_ink.dart';
import 'queue_badge.dart';
import 'rack_fit.dart';

/// Одна клавиша обоймы: значок, подпись и, у загрузок, число задач.
class NavigationKey extends StatelessWidget {
  const NavigationKey({
    super.key,
    required this.targetKey,
    required this.section,
    required this.label,
    required this.icon,
    required this.selected,
    required this.queued,
    required this.fit,
  });

  /// Ключ самой клавиши: по нему плашка выбранного знает, куда перетечь.
  final GlobalKey targetKey;

  final AppSection section;
  final String label;
  final IconData icon;
  final bool selected;

  /// Сколько задач в работе; ноль — метки нет.
  final int queued;

  final RackFit fit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: fit.width,
      child: TextButton(
        key: targetKey,
        onPressed: () =>
            context.read<NavigationBloc>().add(SectionSelected(section)),
        style: _style(colors),
        child: Semantics(
          label: label,
          // Какой раздел открыт, диктор узнаёт так же, как видит глаз:
          // прежде выбранная клавиша звучала ровно как все остальные.
          selected: selected,
          child: ExcludeSemantics(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LiquidSelectionInk(
                    normalColor: colors.textSecondary,
                    selectedColor: colors.onSelection,
                    child: Icon(icon, size: EvaporateIconSize.key),
                  ),
                  if (fit.showLabels) ...[
                    const SizedBox(width: EvaporateSpacing.gap),
                    // Заглавными: короткая подпись на корпусе, а не слово
                    // в предложении. Диктору достаётся обычное слово —
                    // часть читалок разбирает капс по буквам, как
                    // сокращение.
                    Flexible(
                      child: Text(
                        label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                      ),
                    ),
                  ],
                  if (fit.showBadge && queued > 0) ...[
                    const SizedBox(width: EvaporateSpacing.tight),
                    QueueBadge(count: queued, selected: selected),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  ButtonStyle _style(EvaporatePalette colors) => TextButton.styleFrom(
    minimumSize: Size(fit.width, 42),
    padding: const EdgeInsets.symmetric(horizontal: EvaporateSpacing.gap),
    foregroundColor: selected ? colors.onSelection : colors.textSecondary,
    backgroundColor: AppColors.transparent,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    alignment: Alignment.center,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(EvaporateTheme.radiusChip),
    ),
    // Роль метки, как у надписей корпуса: обойма — та же маркировка на
    // корпусе, что и «[ 01 / КОЛЛЕКЦИЯ ]» под ней. Цвет роли не спорит
    // с выбранной клавишей: у кнопки текст красит `foregroundColor`.
    textStyle: EvaporateTypography(colors).label,
  );
}
