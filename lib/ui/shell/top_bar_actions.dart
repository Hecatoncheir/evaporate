import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';

import '../../bloc/navigation/navigation_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../theme.dart';
import '../widgets/window_action.dart';
import '../widgets/window_control.dart';
import 'theme_cycle_action.dart';
import 'top_action.dart';

/// Правый край рейки: поиск, смена оформления, клавиши окна и выход.
class TopBarActions extends StatelessWidget {
  const TopBarActions({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    // Свернуть и развернуть — только когда рамку рисуем мы сами: с рамкой
    // ОС эти клавиши у окна уже есть, и вторых ему не нужно.
    final control = WindowControl.maybeOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TopAction(
          tooltip: l.searchHint,
          icon: Icons.search_rounded,
          onPressed: () =>
              context.read<NavigationBloc>().add(const SearchFocusRequested()),
        ),
        const SizedBox(width: EvaporateSpacing.tight),
        const ThemeCycleAction(),
        const SizedBox(width: EvaporateSpacing.tight),
        if (control != null) ...[
          TopAction(
            key: const ValueKey('rail-minimize'),
            tooltip: l.minimizeWindow,
            icon: Icons.remove,
            onPressed: () =>
                unawaited(runWindowAction(context, windowManager.minimize)),
          ),
          const SizedBox(width: EvaporateSpacing.tight),
          TopAction(
            key: const ValueKey('rail-maximize'),
            tooltip: control.expanded ? l.restoreWindow : l.maximizeWindow,
            icon: control.expanded ? Icons.filter_none : Icons.crop_square,
            onPressed: () => unawaited(control.toggleSize()),
          ),
          const SizedBox(width: EvaporateSpacing.tight),
        ],
        TopAction(
          key: const ValueKey('rail-quit'),
          tooltip: l.quitApp,
          hiddenLabel: l.quitApp,
          icon: Icons.power_settings_new_rounded,
          danger: true,
          onPressed: () => unawaited(windowManager.close()),
        ),
      ],
    );
  }
}
