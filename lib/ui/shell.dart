import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
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
import 'widgets/app_mark.dart';
import 'widgets/common.dart';
import 'widgets/fade_indexed_stack.dart';
import 'widgets/liquid_selection.dart';
import 'widgets/spatial_surface.dart';
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
          body: SpatialBackdrop(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 520;
                return Padding(
                  padding: compact
                      ? const EdgeInsets.symmetric(horizontal: 6)
                      : const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Column(
                    children: [
                      Expanded(
                        child: GameWave(
                          key: const ValueKey('library-wave'),
                          enabled: section == 0 && waveEnabled,
                          child: Row(
                            children: [
                              GlassSurface(
                                radius: compact ? 20 : 28,
                                opacity: context.colors.isDark ? 0.34 : 0.46,
                                child: _Rail(compact: compact),
                              ),
                              SizedBox(width: compact ? 6 : 12),
                              Expanded(
                                child: GlassSurface(
                                  radius: compact ? 20 : 28,
                                  opacity: context.colors.isDark ? 0.58 : 0.68,
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
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 2 : 8),
                      const GlassSurface(
                        radius: 13,
                        opacity: 0.7,
                        shadow: false,
                        child: _StatusBar(),
                      ),
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

class _Rail extends StatefulWidget {
  const _Rail({required this.compact});

  final bool compact;

  @override
  State<_Rail> createState() => _RailState();
}

class _RailState extends State<_Rail> {
  final _targets = List.generate(4, (_) => GlobalKey());

  Widget _ink(Widget child) => LiquidSelectionInk(
    normalColor: context.colors.textSecondary,
    selectedColor: context.colors.onSelection,
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final nav = context.read<NavigationBloc>();
    final section = context.select<NavigationBloc, int>(
      (cubit) => cubit.state.section,
    );
    final activeCount = context.select<DownloadsBloc, int>(
      (cubit) => cubit.state.activeTasks.length,
    );

    return SizedBox(
      width: widget.compact ? 104 : 148,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.railBackground.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(widget.compact ? 20 : 28),
        ),
        child: LiquidSelection(
          key: const ValueKey('rail-liquid'),
          targetKey: () => _targets[section],
          color: context.colors.railIndicator,
          radius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          enabled: context.select<SettingsBloc, bool>(
            (b) => b.state.libraryEffects && b.state.liquidSelectionEnabled,
          ),
          child: FocusTraversalGroup(
            child: NavigationRail(
              backgroundColor: AppColors.transparent,
              indicatorColor: AppColors.transparent,
              selectedIndex: section,
              onDestinationSelected: (index) => nav.add(SectionSelected(index)),
              labelType: NavigationRailLabelType.none,
              leading: widget.compact
                  ? null
                  : Padding(
                      padding: EdgeInsets.only(top: 16, bottom: 8),
                      child: Column(
                        children: [
                          const AppMark(size: 32),
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
                _destination(
                  key: _targets[0],
                  icon: section == 0
                      ? Icons.grid_view_rounded
                      : Icons.grid_view_outlined,
                  label: L.of(context).library,
                ),
                _destination(
                  key: _targets[1],
                  icon: section == 1
                      ? Icons.download_rounded
                      : Icons.download_outlined,
                  label: L.of(context).downloads,
                  badge: activeCount,
                ),
                _destination(
                  key: _targets[2],
                  icon: section == 2 ? Icons.save_rounded : Icons.save_outlined,
                  label: L.of(context).saves,
                ),
                _destination(
                  key: _targets[3],
                  icon: section == 3
                      ? Icons.settings_rounded
                      : Icons.settings_outlined,
                  label: L.of(context).settings,
                ),
              ],
              // Внизу и последней в обходе: закрыть приложение с геймпада
              // иначе нечем — своя панель окна мышью и кнопкой в трее закрытие
              // даёт, а стрелками до них не дойти.
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _QuitButton(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  NavigationRailDestination _destination({
    required GlobalKey key,
    required IconData icon,
    required String label,
    int badge = 0,
  }) {
    return NavigationRailDestination(
      icon: SizedBox(
        key: key,
        width: widget.compact ? 76 : 120,
        height: 48,
        child: _ink(
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Badge(
                isLabelVisible: badge > 0,
                label: Text('$badge'),
                child: Icon(icon, size: 20),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5),
                ),
              ),
            ],
          ),
        ),
      ),
      // Подпись уже входит в саму вертикальную капсулу. Отдельная label
      // NavigationRail создала бы второй невидимый экземпляр текста.
      label: const SizedBox.shrink(),
    );
  }
}

/// Выход из приложения — тем же путём, что и крестик окна.
///
/// `windowManager.close()` не убивает процесс: закрытие перехвачено, и
/// отложенные записи успевают лечь на диск, а движок загрузок — остановиться.
class _QuitButton extends StatelessWidget {
  const _QuitButton();

  @override
  Widget build(BuildContext context) {
    final label = L.of(context).quitApp;
    return Tooltip(
      message: label,
      child: TextButton(
        key: const ValueKey('rail-quit'),
        onPressed: () => unawaited(windowManager.close()),
        style: TextButton.styleFrom(
          foregroundColor: context.colors.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.power_settings_new, size: 22),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
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
      EngineState.failed => (context.colors.danger, Icons.error_outline),
      EngineState.stopped => (
        context.colors.textSecondary,
        Icons.stop_circle_outlined,
      ),
    };

    return Container(
      height: 30,
      color: AppColors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
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
          Spacer(),
          const SizedBox(width: 12),
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              status.message ??
                  L
                      .of(context)
                      .engineStatus(
                        engineStateLabel(L.of(context), status.state),
                      ),
              style: TextStyle(fontSize: 12, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
