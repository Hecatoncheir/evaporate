import 'dart:ui';

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
import '../models/game.dart';
import '../services/download/download_engine.dart';
import 'downloads/downloads_page.dart';
import 'library/game_wave.dart';
import 'library/library_page.dart';
import 'saves/saves_page.dart';
import 'settings/settings_page.dart';
import 'labels.dart';
import 'theme.dart';
import 'widgets/button_hints.dart';
import 'widgets/common.dart';
import 'widgets/fade_indexed_stack.dart';
import 'widgets/spatial_surface.dart';
import '../l10n/app_localizations.dart';
import 'shell/app_footer.dart';
import 'shell/navigation.dart';
import 'shell/top_bar.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  /// Действие кнопки X: сделать с выбранной игрой то же, что делает
  /// главная кнопка её карточки.
  void _primaryAction(BuildContext context) {
    final nav = context.read<NavigationBloc>();
    if (nav.state.section != 0) return;

    final library = context.read<LibraryBloc>();
    final downloads = context.read<DownloadsBloc>();
    final game = library.state.gameById(nav.state.selectedGameId);
    if (game == null) return;

    switch (game.status) {
      case GameStatus.running:
        library.add(GameStopRequested(game));
      case GameStatus.downloading:
        downloads.add(DownloadPauseRequested(game));
      case GameStatus.paused:
        downloads.add(DownloadResumeRequested(game));
      case GameStatus.installed:
        if (game.canLaunch) library.add(GameLaunchRequested(game));
      case GameStatus.notInstalled:
      case GameStatus.error:
        final source = game.source;
        if (source != null && source.kind != GameSourceKind.localFolder) {
          downloads.add(DownloadRequested(game: game, source: source));
        }
    }
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
          body: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/branding/frost_world_background.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
              ),
              ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: ColoredBox(
                    color: context.colors.isDark
                        ? AppColors.frostDark
                        : AppColors.frostLight,
                  ),
                ),
              ),
              LayoutBuilder(
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
                            borderRadius: BorderRadius.circular(12),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: context.colors.surface.withValues(
                                  alpha: context.colors.isDark ? 0.82 : 0.76,
                                ),
                                border: Border.all(
                                  color: context.colors.outline.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                                borderRadius: BorderRadius.circular(12),
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
                                                        b
                                                            .state
                                                            .libraryEffects &&
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
                        if (compact) ...[
                          const SizedBox(height: 8),
                          const ConceptNavigation(compact: true),
                        ],
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
            ],
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

/// Нижняя строка: подсказки управления, скорость обмена и состояние движка.
class DownloadStatusBar extends StatelessWidget {
  const DownloadStatusBar({super.key, required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadsBloc>().state;
    final settings = context.watch<SettingsBloc>().state;
    final gamepad = context.read<GamepadService>();
    final status = downloads.engine;
    final stats = downloads.stats;

    final (color, icon) = switch (status.state) {
      EngineState.ready => (context.colors.accent, Icons.check_circle_outline),
      EngineState.starting => (context.colors.warning, Icons.hourglass_empty),
      EngineState.failed => (context.colors.danger, Icons.error_outline),
      EngineState.stopped => (
        context.colors.textSecondary,
        Icons.stop_circle_outlined,
      ),
    };

    return SizedBox(
      height: compact ? 40 : 46,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final readoutWidth = compact ? 230.0 : 330.0;
          final hintWidth = (constraints.maxWidth - readoutWidth - 10).clamp(
            180.0,
            620.0,
          );
          return Row(
            children: [
              SizedBox(
                width: hintWidth,
                child: GlassSurface(
                  radius: 12,
                  opacity: 0.84,
                  shadow: false,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ValueListenableBuilder<GamepadStatus>(
                      valueListenable: gamepad.status,
                      builder: (context, gamepadStatus, _) => ButtonHints(
                        binding: settings.gamepad,
                        gamepadConnected:
                            settings.gamepad.enabled && gamepadStatus.hasDevice,
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: readoutWidth),
                child: GlassSurface(
                  radius: 12,
                  opacity: 0.92,
                  shadow: false,
                  padding: const EdgeInsets.all(5),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: context.colors.railBackground.withValues(
                        alpha: context.colors.isDark ? 0.92 : 0.7,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: context.colors.outline.withValues(alpha: 0.42),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 7,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(icon, size: 14, color: color),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            status.message ??
                                L
                                    .of(context)
                                    .engineStatus(
                                      engineStateLabel(
                                        L.of(context),
                                        status.state,
                                      ),
                                    ),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.25,
                              color: color,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!compact && stats.activeCount > 0) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.arrow_downward,
                            size: 12,
                            color: context.colors.primary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            speedLabel(L.of(context), stats.downloadSpeed),
                            style: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(width: 9),
                          Icon(
                            Icons.arrow_upward,
                            size: 12,
                            color: context.colors.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            speedLabel(L.of(context), stats.uploadSpeed),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
