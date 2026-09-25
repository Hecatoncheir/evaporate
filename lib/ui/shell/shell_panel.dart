import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/navigation/navigation_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../models/app_section.dart';
import '../../models/library_effect.dart';
import '../library/effects/game_wave.dart';
import '../theme.dart';
import 'hints_bar.dart';
import 'shell_sections.dart';
import 'top_bar.dart';

/// Панель, в которой живут разделы, — с верхней рейкой и строкой
/// подсказок у её краёв.
///
/// Нарочно неплотная: под ней лежит свет выбранной игры, и заливка в упор
/// погасила бы единственный цвет в окне.
///
/// Разделы стоят между рейкой и строкой подсказок, а не под ними.
/// Прокрутка, догоняя фокус со стрелок и геймпада, ставит выбранное к
/// краю видимой области, и под рейкой оно пряталось бы — а нажатие
/// уходило бы в неё. Под рейку и строку уходит фон панели: волна и свет
/// игр, и им есть что показать сквозь себя.
class ShellPanel extends StatelessWidget {
  const ShellPanel({super.key, required this.hints});

  /// Есть ли строка подсказок: в низком окне её нет, и места под неё
  /// разделы не оставляют.
  final bool hints;

  @override
  Widget build(BuildContext context) {
    final section = context.select<NavigationBloc, AppSection>(
      (bloc) => bloc.state.section,
    );
    final waveEnabled = context.select<SettingsBloc, bool>(
      (bloc) => bloc.state.appearance.shows(LibraryEffect.waves),
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
          enabled: section == AppSection.library && waveEnabled,
          child: Stack(
            children: [
              Positioned.fill(
                top: EvaporateLayout.topBarHeight,
                bottom: hints ? EvaporateLayout.hintsHeight : 0,
                child: FocusTraversalGroup(child: const ShellSections()),
              ),
              const Positioned(top: 0, left: 0, right: 0, child: TopBar()),
              if (hints)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: HintsBar(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
