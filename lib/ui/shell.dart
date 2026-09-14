import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/downloads/downloads_bloc.dart';
import '../bloc/library/library_bloc.dart';
import '../bloc/navigation/navigation_bloc.dart';
import '../bloc/settings/settings_bloc.dart';
import '../input/gamepad_service.dart';
import '../input/input_scope.dart';
import '../bloc/notice.dart';
import '../models/app_settings.dart';
import 'downloads/downloads_page.dart';
import 'library/game_wave.dart';
import 'library/library_page.dart';
import 'library/primary_action.dart';
import 'saves/saves_page.dart';
import 'settings/settings_page.dart';
import 'theme.dart';
import 'widgets/ambient_light.dart';
import 'widgets/common.dart';
import 'widgets/fade_indexed_stack.dart';
import 'shell/app_footer.dart';
import 'shell/top_bar.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  /// Действие кнопки X: сделать с выбранной игрой то же, что делает
  /// главная кнопка её карточки. Решение о том, что это за действие, —
  /// общее (`primary_action.dart`), иначе геймпад и кадр библиотеки
  /// однажды разошлись бы на одном состоянии игры.
  void _primaryAction(BuildContext context) {
    final nav = context.read<NavigationBloc>();
    if (nav.state.section != 0) return;

    final game = context.read<LibraryBloc>().state.gameById(
      nav.state.selectedGameId,
    );
    if (game == null) return;
    dispatchPrimaryAction(context, game);
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.read<NavigationBloc>();
    final gamepad = context.read<GamepadService>();
    final section = context.select<NavigationBloc, int>(
      (bloc) => bloc.state.section,
    );
    final waveEnabled = context.select<SettingsBloc, bool>(
      (bloc) => bloc.state.libraryEffects && bloc.state.wavesEnabled,
    );
    final ambientEnabled = context.select<SettingsBloc, bool>(
      (bloc) => bloc.state.libraryEffects && bloc.state.ambientEnabled,
    );
    // Свет корпуса берётся от выбранной игры, поэтому оболочке нужно и то,
    // что выбрано, и название — два разных блока.
    final selectedId = context.select<NavigationBloc, String?>(
      (bloc) => bloc.state.selectedGameId,
    );
    final selectedTitle = context.select<LibraryBloc, String?>(
      (bloc) => bloc.state.gameById(selectedId)?.title,
    );

    return MultiBlocListener(
      listeners: [
        // Раскладка живёт в настройках, применять её должен сервис ввода.
        BlocListener<SettingsBloc, AppSettings>(
          listenWhen: (a, b) => a.gamepad != b.gamepad,
          listener: (context, settings) => gamepad.binding = settings.gamepad,
        ),
        // Сообщения об операциях приходят из кубитов, а не из виджетов.
        BlocListener<LibraryBloc, LibraryState>(
          listenWhen: (a, b) => a.notice != b.notice,
          listener: (context, state) => _showNotice(context, state.notice),
        ),
        BlocListener<DownloadsBloc, DownloadsState>(
          listenWhen: (a, b) => a.notice != b.notice,
          listener: (context, state) => _showNotice(context, state.notice),
        ),
      ],
      child: InputScope(
        gamepad: gamepad,
        onSectionChange: (delta) => nav.add(SectionCycled(delta)),
        onPrimaryAction: () => _primaryAction(context),
        onSearch: () => nav.add(const SearchFocusRequested()),
        onBack: nav.closeOpenedGame,
        child: Scaffold(
          backgroundColor: AppColors.transparent,
          body: AmbientLight(
            enabled: ambientEnabled,
            title: selectedTitle,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 980;
                final shortViewport = constraints.maxHeight < 520;
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 6 : 10,
                    compact ? 6 : 10,
                    compact ? 6 : 10,
                    0,
                  ),
                  child: Column(
                    children: [
                      ConceptTopBar(compact: compact),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            EvaporateTheme.radiusPanel,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              // Панель нарочно неплотная: под ней лежит свет
                              // выбранной игры, и заливка в упор погасила бы
                              // единственный цвет в окне.
                              color: context.colors.surface.withValues(
                                alpha: context.colors.isDark ? 0.62 : 0.78,
                              ),
                              border: Border.all(
                                color: context.colors.outline.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                              borderRadius: BorderRadius.circular(
                                EvaporateTheme.radiusPanel,
                              ),
                            ),
                            child: GameWave(
                              key: const ValueKey('library-wave'),
                              enabled: section == 0 && waveEnabled,
                              child: FocusTraversalGroup(
                                child:
                                    BlocSelector<
                                      NavigationBloc,
                                      NavigationState,
                                      int
                                    >(
                                      selector: (state) => state.section,
                                      builder: (context, section) =>
                                          FadeIndexedStack(
                                            index: section,
                                            enabled: context
                                                .select<SettingsBloc, bool>(
                                                  (b) =>
                                                      b.state.libraryEffects &&
                                                      b
                                                          .state
                                                          .interfaceAnimationsEnabled,
                                                ),
                                            children: const [
                                              LibraryPage(),
                                              DownloadsPage(),
                                              SavesPage(),
                                              SettingsPage(),
                                            ],
                                          ),
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (!shortViewport) ...[
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 40,
                          child: OverflowBox(
                            maxWidth: constraints.maxWidth,
                            child: SizedBox(
                              width: constraints.maxWidth,
                              child: const AppFooter(),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  static void _showNotice(BuildContext context, Notice? notice) {
    if (notice == null) return;
    if (notice.isError) {
      showError(context, notice.message);
    } else {
      showInfo(context, notice.message);
    }
  }
}
