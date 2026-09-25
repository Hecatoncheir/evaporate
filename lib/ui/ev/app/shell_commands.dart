import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/library/library_bloc.dart';
import '../../../bloc/navigation/navigation_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/app_section.dart';
import '../../labels.dart';
import '../shell/ev_palette.dart';
import '../shell/ev_shell.dart';
import '../widgets/ev_icon.dart';

/// Строки палитры «Поиск и команды»: разделы окна и игры библиотеки.
///
/// Собираются в миг открытия палитры — библиотека к тому времени могла
/// измениться. Разделы идут первыми: их четыре, и пустой запрос должен
/// показывать их, а не первые девять игр большой библиотеки.
List<EvCommand> shellCommands(BuildContext context, EvShellController shell) {
  final l = L.of(context);
  final nav = context.read<NavigationBloc>();
  final games = context.read<LibraryBloc>().state.games;
  return [
    for (final (i, section) in shell.sections.indexed)
      EvCommand(
        title: section.labelOf(l),
        subtitle: l.evPaletteSection(i + 1),
        icon: section.icon,
        hint: l.evPaletteOpen,
        onRun: () => shell.go(section),
      ),
    for (final game in games)
      EvCommand(
        title: game.title,
        subtitle: gameStatusLabel(l, game.status),
        icon: EvIcons.library,
        hint: l.evPaletteOpen,
        // Страница игры живёт в библиотеке: сперва туда, потом она.
        onRun: () => nav
          ..add(const SectionSelected(AppSection.library))
          ..add(GameOpened(game.id)),
      ),
  ];
}
