import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../models/app_section.dart';
import '../../models/library_effect.dart';
import '../theme.dart';
import '../widgets/liquid/liquid_selection.dart';
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
  final Map<AppSection, GlobalKey> targets;

  final Map<AppSection, String> labels;
  final Map<AppSection, IconData> icons;
  final AppSection section;

  /// Сколько задач в работе у раздела. Нет записи — метки нет.
  final Map<AppSection, int> queuedAt;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, box) {
        final fit = RackFit.forRack(box, AppSection.values.length);
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
              (b) => b.state.appearance.shows(LibraryEffect.liquidSelection),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final value in AppSection.values)
                  NavigationKey(
                    targetKey: targets[value]!,
                    section: value,
                    label: labels[value]!,
                    icon: icons[value]!,
                    selected: section == value,
                    queued: queuedAt[value] ?? 0,
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
