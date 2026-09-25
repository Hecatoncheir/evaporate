import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/navigation/navigation_bloc.dart';
import '../../models/app_section.dart';
import '../theme.dart';
import '../widgets/liquid/liquid_selection_ink.dart';
import 'queue_badge.dart';
import 'rail_tooltip.dart';

/// Одна клавиша обоймы: значок раздела и, у загрузок, число задач.
///
/// Подписи на клавише нет: имя открытого раздела стоит в крошке верхней
/// рейки, а имя любого — в подсказке сбоку, под курсором и в фокусе.
/// Диктору подпись достаётся всегда: без неё обойма звучала бы четырьмя
/// безымянными кнопками.
class NavigationKey extends StatelessWidget {
  const NavigationKey({
    super.key,
    required this.targetKey,
    required this.section,
    required this.label,
    required this.icon,
    required this.selected,
    required this.queued,
  });

  /// Ключ самой клавиши: по нему капля выбранного знает, куда перетечь.
  final GlobalKey targetKey;

  final AppSection section;
  final String label;
  final IconData icon;
  final bool selected;

  /// Сколько задач в работе; ноль — метки нет.
  final int queued;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return RailTooltip(
      message: label,
      child: SizedBox.fromSize(
        size: EvaporateLayout.railKey,
        child: TextButton(
          key: targetKey,
          onPressed: () =>
              context.read<NavigationBloc>().add(SectionSelected(section)),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: selected
                ? colors.onSelection
                : colors.textSecondary,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(EvaporateTheme.radiusControl),
            ),
          ),
          child: Semantics(
            label: label,
            // Какой раздел открыт, диктор узнаёт так же, как видит глаз:
            // прежде выбранная клавиша звучала ровно как все остальные.
            selected: selected,
            // Метка стоит в углу клавиши, а не значка: слой во всю клавишу,
            // иначе он сжимался по значку, и метка ложилась на сам значок.
            child: ExcludeSemantics(
              child: SizedBox.expand(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    LiquidSelectionInk(
                      normalColor: colors.textSecondary,
                      selectedColor: colors.onSelection,
                      child: Icon(icon, size: EvaporateIconSize.panel),
                    ),
                    if (queued > 0)
                      Positioned(
                        top: EvaporateSpacing.hair,
                        right: EvaporateSpacing.hair,
                        child: QueueBadge(count: queued, selected: selected),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
