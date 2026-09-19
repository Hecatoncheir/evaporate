import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../theme.dart';
import '../widgets/liquid_selection.dart';
import 'navigation_key.dart';
import 'rack_fit.dart';

/// Сама обойма: корпус, плашка выбранного и четыре клавиши в ряд.
class NavigationRack extends StatelessWidget {
  const NavigationRack({
    super.key,
    required this.targets,
    required this.labels,
    required this.icons,
    required this.section,
    required this.queuedAt,
  });

  /// Ключи клавиш: за ними следует плашка выбранного.
  final List<GlobalKey> targets;

  final List<String> labels;
  final List<IconData> icons;
  final int section;

  /// Сколько задач в работе у каждого раздела; у большинства ноль.
  final List<int> queuedAt;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, box) {
        final fit = RackFit.forRack(box, labels.length);
        return Container(
          key: const ValueKey('concept-navigation'),
          height: EvaporateLayout.railHeight,
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
                blurRadius: HardwareSurfaceTheme.of(context).railShadowBlur,
                offset: Offset(
                  0,
                  HardwareSurfaceTheme.of(context).railShadowDrop,
                ),
              ),
            ],
          ),
          child: LiquidSelection(
            key: const ValueKey('rail-liquid'),
            targetKey: () => targets[section],
            color: colors.selection,
            radius: EvaporateTheme.radiusChip,
            enabled: context.select<SettingsBloc, bool>(
              (b) => b.state.libraryEffects && b.state.liquidSelectionEnabled,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < labels.length; index++)
                  NavigationKey(
                    targetKey: targets[index],
                    index: index,
                    label: labels[index],
                    icon: icons[index],
                    selected: section == index,
                    queued: queuedAt[index],
                    fit: fit,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
