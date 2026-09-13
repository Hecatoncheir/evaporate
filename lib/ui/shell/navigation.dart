import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/navigation/navigation_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../theme.dart';
import '../widgets/liquid_selection.dart';
import '../../l10n/app_localizations.dart';

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
    return Container(
      key: ValueKey(
        widget.compact ? 'concept-navigation-compact' : 'concept-navigation',
      ),
      height: widget.compact ? 54 : 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.railBackground,
        border: Border.all(
          color: context.colors.outline.withValues(alpha: 0.42),
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.coverTextShadow.withValues(
              alpha: context.colors.isDark ? 0.2 : 0.1,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LiquidSelection(
        key: const ValueKey('rail-liquid'),
        targetKey: () => _targets[section],
        color: context.colors.selection,
        radius: 8,
        enabled: context.select<SettingsBloc, bool>(
          (b) => b.state.libraryEffects && b.state.liquidSelectionEnabled,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(labels.length, (index) {
            final selected = section == index;
            return Padding(
              padding: EdgeInsets.only(
                right: index == labels.length - 1 ? 0 : 3,
              ),
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
                        normalColor: context.colors.textSecondary,
                        selectedColor: context.colors.onSelection,
                        child: Icon(icons[index], size: 17),
                      ),
                      if (!widget.compact ||
                          MediaQuery.sizeOf(context).width > 560) ...[
                        const SizedBox(width: 8),
                        Text(labels[index]),
                      ],
                      if (index == 1 && count > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          constraints: const BoxConstraints(minWidth: 18),
                          height: 18,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: context.colors.primary,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              color: context.colors.onPrimary,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                style: TextButton.styleFrom(
                  minimumSize: Size(widget.compact ? 50 : 104, 42),
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.compact ? 10 : 14,
                  ),
                  foregroundColor: selected
                      ? context.colors.onSelection
                      : context.colors.textSecondary,
                  backgroundColor: AppColors.transparent,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  alignment: Alignment.center,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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
