import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/navigation/navigation_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../library/game_wave.dart';
import '../theme.dart';
import 'shell_sections.dart';

/// Панель, в которой живут разделы.
///
/// Нарочно неплотная: под ней лежит свет выбранной игры, и заливка в упор
/// погасила бы единственный цвет в окне.
class ShellPanel extends StatelessWidget {
  const ShellPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final section = context.select<NavigationBloc, int>(
      (bloc) => bloc.state.section,
    );
    final waveEnabled = context.select<SettingsBloc, bool>(
      (bloc) => bloc.state.libraryEffects && bloc.state.wavesEnabled,
    );
    final radius = BorderRadius.circular(EvaporateTheme.radiusPanel);
    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.surface.withValues(
            alpha: HardwareSurfaceTheme.of(context).shellOpacity,
          ),
          border: Border.all(
            color: context.colors.outline.withValues(alpha: EvaporateAlpha.rim),
          ),
          borderRadius: radius,
        ),
        child: GameWave(
          key: const ValueKey('library-wave'),
          // Волна — украшение библиотеки: в других разделах её нет.
          enabled: section == 0 && waveEnabled,
          child: FocusTraversalGroup(child: const ShellSections()),
        ),
      ),
    );
  }
}
