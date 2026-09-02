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
import 'library/library_page.dart';
import 'saves/saves_page.dart';
import 'settings/settings_page.dart';
import 'labels.dart';
import 'theme.dart';
import 'widgets/button_hints.dart';
import 'widgets/common.dart';
import 'widgets/fade_indexed_stack.dart';
import '../l10n/app_localizations.dart';

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
        child: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const _Rail(),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: FocusTraversalGroup(
                        child:
                            BlocSelector<NavigationBloc, NavigationState, int>(
                              selector: (state) => state.section,
                              builder: (context, section) => FadeIndexedStack(
                                index: section,
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
                  ],
                ),
              ),
              const _StatusBar(),
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

class _Rail extends StatelessWidget {
  const _Rail();

  @override
  Widget build(BuildContext context) {
    final nav = context.read<NavigationBloc>();
    final section = context.select<NavigationBloc, int>(
      (cubit) => cubit.state.section,
    );
    final activeCount = context.select<DownloadsBloc, int>(
      (cubit) => cubit.state.activeTasks.length,
    );

    return FocusTraversalGroup(
      child: NavigationRail(
        selectedIndex: section,
        onDestinationSelected: (index) => nav.add(SectionSelected(index)),
        labelType: NavigationRailLabelType.all,
        leading: Padding(
          padding: EdgeInsets.only(top: 16, bottom: 8),
          child: Column(
            children: [
              Icon(
                Icons.water_drop_outlined,
                color: context.colors.primary,
                size: 26,
              ),
              SizedBox(height: 6),
              Text(
                'Evaporate',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        destinations: [
          NavigationRailDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: Text(L.of(context).library),
          ),
          NavigationRailDestination(
            icon: Badge(
              isLabelVisible: activeCount > 0,
              label: Text('$activeCount'),
              child: const Icon(Icons.download_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: activeCount > 0,
              label: Text('$activeCount'),
              child: const Icon(Icons.download_rounded),
            ),
            label: Text(L.of(context).downloads),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.save_outlined),
            selectedIcon: Icon(Icons.save_rounded),
            label: Text(L.of(context).saves),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: Text(L.of(context).settings),
          ),
        ],
      ),
    );
  }
}

/// Нижняя строка: подсказки управления, скорость обмена и состояние движка.
class _StatusBar extends StatelessWidget {
  const _StatusBar();

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
      EngineState.missingBinary => (
        context.colors.warning,
        Icons.warning_amber_rounded,
      ),
      EngineState.failed => (context.colors.danger, Icons.error_outline),
      EngineState.stopped => (
        context.colors.textSecondary,
        Icons.stop_circle_outlined,
      ),
    };

    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: context.colors.railBackground,
        border: Border(top: BorderSide(color: context.colors.outline)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          ValueListenableBuilder<GamepadStatus>(
            valueListenable: gamepad.status,
            builder: (context, gamepadStatus, _) => ButtonHints(
              binding: settings.gamepad,
              gamepadConnected:
                  settings.gamepad.enabled && gamepadStatus.hasDevice,
            ),
          ),
          const Spacer(),
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            status.message ??
                L
                    .of(context)
                    .engineStatus(
                      engineStateLabel(L.of(context), status.state),
                    ),
            style: TextStyle(fontSize: 12, color: color),
          ),
          if (stats.activeCount > 0) ...[
            const SizedBox(width: 16),
            Icon(Icons.arrow_downward, size: 13, color: context.colors.primary),
            const SizedBox(width: 3),
            Text(
              speedLabel(L.of(context), stats.downloadSpeed),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 14),
            Icon(
              Icons.arrow_upward,
              size: 13,
              color: context.colors.textSecondary,
            ),
            const SizedBox(width: 3),
            Text(
              speedLabel(L.of(context), stats.uploadSpeed),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
