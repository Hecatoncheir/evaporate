import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';

import '../../bloc/navigation/navigation_bloc.dart';
import '../../l10n/app_localizations.dart';
import 'theme_cycle_action.dart';
import 'top_action.dart';
import 'window_actions.dart';

/// Правый край рейки: поиск, смена оформления, клавиши окна и выход.
class TopBarActions extends StatelessWidget {
  const TopBarActions({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TopAction(
          tooltip: l.searchHint,
          icon: Icons.search_rounded,
          onPressed: () =>
              context.read<NavigationBloc>().add(const SearchFocusRequested()),
        ),
        const SizedBox(width: 7),
        const ThemeCycleAction(),
        const SizedBox(width: 7),
        const WindowActions(),
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
