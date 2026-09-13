import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/navigation/navigation_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../theme.dart';
import '../widgets/app_mark.dart';
import '../../l10n/app_localizations.dart';
import 'navigation.dart';

/// Верхняя панель концепции: бренд и действия стоят по краям, а разделы —
/// ровно по центру доступной ширины. В узком окне разделы переезжают вниз.
class ConceptTopBar extends StatelessWidget {
  const ConceptTopBar({super.key, required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsBloc>().state;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: [
              const AppMark(size: 36),
              if (!compact) ...[
                const SizedBox(width: 10),
                Text(
                  'EVAPORATE',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontFamily: EvaporateTheme.monoFontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
              const Spacer(),
              TopAction(
                tooltip: L.of(context).searchHint,
                icon: Icons.search_rounded,
                onPressed: () => context.read<NavigationBloc>().add(
                  const SearchFocusRequested(),
                ),
              ),
              const SizedBox(width: 8),
              TopAction(
                tooltip: dark
                    ? L.of(context).lightThemeAction
                    : L.of(context).darkThemeAction,
                icon: dark
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
                onPressed: () {
                  context.read<SettingsBloc>().add(
                    SettingsChanged(
                      settings.copyWith(
                        themeMode: dark ? ThemeMode.light : ThemeMode.dark,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              TopAction(
                key: const ValueKey('rail-quit'),
                tooltip: L.of(context).quitApp,
                hiddenLabel: L.of(context).quitApp,
                icon: Icons.power_settings_new_rounded,
                onPressed: () => unawaited(windowManager.close()),
              ),
            ],
          ),
          if (!compact) const ConceptNavigation(compact: false),
        ],
      ),
    );
  }
}

class TopAction extends StatelessWidget {
  const TopAction({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.hiddenLabel,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final String? hiddenLabel;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Stack(
      alignment: Alignment.center,
      children: [
        Icon(icon, size: 20),
        if (hiddenLabel case final label?)
          SizedBox.shrink(child: ExcludeSemantics(child: Text(label))),
      ],
    ),
    style: IconButton.styleFrom(
      minimumSize: const Size(42, 42),
      backgroundColor: context.colors.surfaceHigh.withValues(alpha: 0.62),
      foregroundColor: context.colors.textSecondary,
      side: BorderSide(color: context.colors.outline.withValues(alpha: 0.45)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}
