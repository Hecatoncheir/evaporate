import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/navigation/navigation_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../models/app_section.dart';
import '../downloads/downloads_page.dart';
import '../library/library_page.dart';
import '../saves/saves_page.dart';
import '../settings/settings_page.dart';
import '../widgets/fade_indexed_stack.dart';

/// Четыре раздела приложения.
///
/// Лежат в стопке все разом: невидимый раздел не выброшен, а только не
/// нарисован, — переход между разделами не собирает страницу заново.
class ShellSections extends StatelessWidget {
  const ShellSections({super.key});

  @override
  Widget build(BuildContext context) {
    final section = context.select<NavigationBloc, AppSection>(
      (bloc) => bloc.state.section,
    );
    final animated = context.select<SettingsBloc, bool>(
      (bloc) =>
          bloc.state.libraryEffects && bloc.state.interfaceAnimationsEnabled,
    );
    return FadeIndexedStack(
      index: section.index,
      enabled: animated,
      children: const [
        LibraryPage(),
        DownloadsPage(),
        SavesPage(),
        SettingsPage(),
      ],
    );
  }
}
