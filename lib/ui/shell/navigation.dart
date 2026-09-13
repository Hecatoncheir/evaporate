import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/navigation/navigation_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../theme.dart';
import '../widgets/liquid_selection.dart';
import '../../l10n/app_localizations.dart';

/// Разделы приложения: четыре клавиши в одной обойме и плашка выбранного,
/// которая переезжает между ними.
///
/// Клавиши **одной ширины**, хотя подписи разной длины. Так плашка едет
/// ровным шагом, ряд читается как один орган управления, а не как четыре
/// кнопки подряд, и при смене языка обойма не меняет размер.
class ConceptNavigation extends StatefulWidget {
  const ConceptNavigation({super.key, required this.compact});

  final bool compact;

  @override
  State<ConceptNavigation> createState() => _ConceptNavigationState();
}

class _ConceptNavigationState extends State<ConceptNavigation> {
  final _targets = List.generate(4, (_) => GlobalKey());

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final section = context.select<NavigationBloc, int>(
      (bloc) => bloc.state.section,
    );
    final count = context.select<DownloadsBloc, int>(
      (bloc) => bloc.state.activeTasks.length,
    );
    final labels = [
      L.of(context).library,
      L.of(context).downloads,
      L.of(context).saves,
      L.of(context).settings,
    ];
    const icons = [
      Icons.grid_view_outlined,
      Icons.download_rounded,
      Icons.save_rounded,
      Icons.settings_rounded,
    ];
    final width = widget.compact ? 56.0 : 130.0;

    return Container(
      key: ValueKey(
        widget.compact ? 'concept-navigation-compact' : 'concept-navigation',
      ),
      height: widget.compact ? 52 : 48,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.railBackground,
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(EvaporateTheme.radiusPanel),
        boxShadow: [
          // Ночью обойма лежит в мягкой тени, днём — на коротком жёстком
          // торце: один и тот же приём выглядел бы на светлом грязью.
          BoxShadow(
            color: colors.shadow,
            blurRadius: colors.isDark ? 22 : 8,
            offset: Offset(0, colors.isDark ? 10 : 2),
          ),
        ],
      ),
      child: LiquidSelection(
        key: const ValueKey('rail-liquid'),
        targetKey: () => _targets[section],
        color: colors.selection,
        radius: EvaporateTheme.radiusChip,
        enabled: context.select<SettingsBloc, bool>(
          (b) => b.state.libraryEffects && b.state.liquidSelectionEnabled,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(labels.length, (index) {
            final selected = section == index;
            return SizedBox(
              width: width,
              child: TextButton(
                key: _targets[index],
                onPressed: () =>
                    context.read<NavigationBloc>().add(SectionSelected(index)),
                // ignore: sort_child_properties_last
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      LiquidSelectionInk(
                        normalColor: colors.textSecondary,
                        selectedColor: colors.onSelection,
                        child: Icon(icons[index], size: 16),
                      ),
                      if (!widget.compact ||
                          MediaQuery.sizeOf(context).width > 560) ...[
                        const SizedBox(width: 8),
                        // Заглавными: короткая подпись на корпусе, а не
                        // слово в предложении. Диктору при этом достаётся
                        // обычное слово — часть читалок разбирает капс по
                        // буквам, как сокращение.
                        Flexible(
                          child: Semantics(
                            label: labels[index],
                            child: ExcludeSemantics(
                              child: Text(
                                labels[index].toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.fade,
                                softWrap: false,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (index == 1 && count > 0) ...[
                        const SizedBox(width: 6),
                        _QueueBadge(count: count, selected: selected),
                      ],
                    ],
                  ),
                ),
                style: TextButton.styleFrom(
                  minimumSize: Size(width, 42),
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.compact ? 6 : 10,
                  ),
                  foregroundColor: selected
                      ? colors.onSelection
                      : colors.textSecondary,
                  backgroundColor: AppColors.transparent,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  alignment: Alignment.center,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      EvaporateTheme.radiusChip,
                    ),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Сколько задач в работе. На выбранной клавише метка выворачивается:
/// золотая метка на золотой плашке пропала бы.
class _QueueBadge extends StatelessWidget {
  const _QueueBadge({required this.count, required this.selected});

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedContainer(
      duration: context.motion.fast,
      curve: EvaporateMotion.ease,
      constraints: const BoxConstraints(minWidth: 17),
      height: 17,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: selected ? colors.onSelection : colors.primaryFill,
        borderRadius: BorderRadius.circular(EvaporateTheme.radiusChip),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: selected ? colors.selection : colors.onPrimary,
          fontFamily: EvaporateTheme.monoFontFamily,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
