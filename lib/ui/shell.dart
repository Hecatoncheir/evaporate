import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

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
                        _ConceptTopBar(compact: compact),
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
                          const _ConceptNavigation(compact: true),
                        ],
                        if (!shortViewport) ...[
                          const SizedBox(height: 6),
                        SizedBox(
                          height: 40,
                          child: OverflowBox(
                            maxWidth: constraints.maxWidth,
                            child: SizedBox(
                              width: constraints.maxWidth,
                              child: const _AppFooter(),
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

/// Верхняя панель концепции: бренд и действия стоят по краям, а разделы —
/// ровно по центру доступной ширины. В узком окне разделы переезжают вниз.
class _ConceptTopBar extends StatelessWidget {
  const _ConceptTopBar({required this.compact});

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
              _TopAction(
                tooltip: L.of(context).searchHint,
                icon: Icons.search_rounded,
                onPressed: () => context.read<NavigationBloc>().add(
                  const SearchFocusRequested(),
                ),
              ),
              const SizedBox(width: 8),
              _TopAction(
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
              _TopAction(
                key: const ValueKey('rail-quit'),
                tooltip: L.of(context).quitApp,
                hiddenLabel: L.of(context).quitApp,
                icon: Icons.power_settings_new_rounded,
                onPressed: () => unawaited(windowManager.close()),
              ),
            ],
          ),
          if (!compact) const _ConceptNavigation(compact: false),
        ],
      ),
    );
  }
}

class _TopAction extends StatelessWidget {
  const _TopAction({
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

class _ConceptNavigation extends StatefulWidget {
  const _ConceptNavigation({required this.compact});

  final bool compact;

  @override
  State<_ConceptNavigation> createState() => _ConceptNavigationState();
}

class _ConceptNavigationState extends State<_ConceptNavigation> {
  final _targets = List.generate(4, (_) => GlobalKey());

  @override
  Widget build(BuildContext context) {
    final section = context.select<NavigationBloc, int>(
      (bloc) => bloc.state.section,
    );
    final count = context.select<DownloadsBloc, int>(
      (bloc) => bloc.state.activeTasks.length,
    );
    final labels = [
      L.of(context).library,
      L.of(context).downloads,
      L.of(context).saves,
      L.of(context).settings,
    ];
    const icons = [
      Icons.grid_view_outlined,
      Icons.download_rounded,
      Icons.save_rounded,
      Icons.settings_rounded,
    ];
    return Container(
      key: ValueKey(
        widget.compact ? 'concept-navigation-compact' : 'concept-navigation',
      ),
      height: widget.compact ? 54 : 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.railBackground,
        border: Border.all(
          color: context.colors.outline.withValues(alpha: 0.42),
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.coverTextShadow.withValues(
              alpha: context.colors.isDark ? 0.2 : 0.1,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LiquidSelection(
        key: const ValueKey('rail-liquid'),
        targetKey: () => _targets[section],
        color: context.colors.selection,
        radius: 8,
        enabled: context.select<SettingsBloc, bool>(
          (b) => b.state.libraryEffects && b.state.liquidSelectionEnabled,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(labels.length, (index) {
            final selected = section == index;
            return Padding(
              padding: EdgeInsets.only(
                right: index == labels.length - 1 ? 0 : 3,
              ),
              child: TextButton(
                key: _targets[index],
                onPressed: () =>
                    context.read<NavigationBloc>().add(SectionSelected(index)),
                // ignore: sort_child_properties_last
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      LiquidSelectionInk(
                        normalColor: context.colors.textSecondary,
                        selectedColor: context.colors.onSelection,
                        child: Icon(icons[index], size: 17),
                      ),
                      if (!widget.compact ||
                          MediaQuery.sizeOf(context).width > 560) ...[
                        const SizedBox(width: 8),
                        Text(labels[index]),
                      ],
                      if (index == 1 && count > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          constraints: const BoxConstraints(minWidth: 18),
                          height: 18,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: context.colors.primary,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              color: context.colors.onPrimary,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                style: TextButton.styleFrom(
                  minimumSize: Size(widget.compact ? 50 : 104, 42),
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.compact ? 10 : 14,
                  ),
                  foregroundColor: selected
                      ? context.colors.onSelection
                      : context.colors.textSecondary,
                  backgroundColor: AppColors.transparent,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  alignment: Alignment.center,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
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
      width: widget.compact ? 78 : 194,
      child: LiquidSelection(
        key: const ValueKey('rail-liquid'),
        targetKey: () => _targets[section],
        color: context.colors.railIndicator,
        radius: 12,
        padding: const EdgeInsets.all(2),
        enabled: context.select<SettingsBloc, bool>(
          (b) => b.state.libraryEffects && b.state.liquidSelectionEnabled,
        ),
        child: FocusTraversalGroup(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              widget.compact ? 8 : 12,
              widget.compact ? 10 : 14,
              widget.compact ? 8 : 12,
              10,
            ),
            child: Column(
              children: [
                _RailHeader(compact: widget.compact),
                SizedBox(height: widget.compact ? 18 : 24),
                _destination(
                  key: _targets[0],
                  index: '01',
                  selected: section == 0,
                  icon: section == 0
                      ? Icons.grid_view_rounded
                      : Icons.grid_view_outlined,
                  label: L.of(context).library,
                  onPressed: () => nav.add(const SectionSelected(0)),
                ),
                const SizedBox(height: 10),
                _destination(
                  key: _targets[1],
                  index: '02',
                  selected: section == 1,
                  icon: section == 1
                      ? Icons.download_rounded
                      : Icons.download_outlined,
                  label: L.of(context).downloads,
                  badge: activeCount,
                  onPressed: () => nav.add(const SectionSelected(1)),
                ),
                const SizedBox(height: 10),
                _destination(
                  key: _targets[2],
                  index: '03',
                  selected: section == 2,
                  icon: section == 2 ? Icons.save_rounded : Icons.save_outlined,
                  label: L.of(context).saves,
                  onPressed: () => nav.add(const SectionSelected(2)),
                ),
                const SizedBox(height: 10),
                _destination(
                  key: _targets[3],
                  index: '04',
                  selected: section == 3,
                  icon: section == 3
                      ? Icons.settings_rounded
                      : Icons.settings_outlined,
                  label: L.of(context).settings,
                  onPressed: () => nav.add(const SectionSelected(3)),
                ),
                const Spacer(),
                _QuitButton(compact: widget.compact),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _destination({
    required GlobalKey key,
    required String index,
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    int badge = 0,
  }) {
    return _TactileNavKey(
      key: key,
      compact: widget.compact,
      index: index,
      selected: selected,
      label: label,
      onPressed: onPressed,
      child: _ink(
        Badge(
          isLabelVisible: badge > 0,
          label: Text('$badge'),
          child: Icon(icon, size: widget.compact ? 21 : 20),
        ),
      ),
    );
  }
}

class _RailHeader extends StatelessWidget {
  const _RailHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) return const AppMark(size: 34);
    return Row(
      children: [
        const AppMark(size: 38),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EVAPORATE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const HardwareGrille(width: 112, height: 28),
            ],
          ),
        ),
      ],
    );
  }
}

class _TactileNavKey extends StatelessWidget {
  const _TactileNavKey({
    super.key,
    required this.compact,
    required this.index,
    required this.selected,
    required this.label,
    required this.onPressed,
    required this.child,
  });

  final bool compact;
  final String index;
  final bool selected;
  final String label;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(12);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: compact ? label : '',
        child: AnimatedScale(
          scale: selected ? 0.985 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            height: compact ? 54 : 58,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.transparent
                  : colors.surfaceHigh.withValues(
                      alpha: colors.isDark ? 0.52 : 0.74,
                    ),
              borderRadius: radius,
              border: Border.all(
                color: selected
                    ? colors.textPrimary.withValues(alpha: 0.22)
                    : colors.textPrimary.withValues(
                        alpha: colors.isDark ? 0.1 : 0.32,
                      ),
              ),
              boxShadow: selected
                  ? null
                  : [
                      BoxShadow(
                        color: colors.isDark
                            ? AppColors.hardwareShadowDark
                            : AppColors.hardwareShadowLight,
                        blurRadius: 8,
                        offset: const Offset(4, 5),
                      ),
                      BoxShadow(
                        color: colors.textPrimary.withValues(
                          alpha: colors.isDark ? 0.04 : 0.14,
                        ),
                        blurRadius: 5,
                        offset: const Offset(-2, -2),
                      ),
                    ],
            ),
            child: Material(
              color: AppColors.transparent,
              borderRadius: radius,
              child: InkWell(
                borderRadius: radius,
                onTap: onPressed,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14),
                  child: Row(
                    mainAxisAlignment: compact
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      child,
                      if (compact)
                        SizedBox.shrink(
                          child: ExcludeSemantics(child: Text(label)),
                        ),
                      if (!compact) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ).copyWith(
                                  color: selected
                                      ? colors.onSelection
                                      : colors.textSecondary,
                                ),
                          ),
                        ),
                        Text(
                          index,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                            color: selected
                                ? colors.onSelection.withValues(alpha: 0.56)
                                : colors.textSecondary.withValues(alpha: 0.56),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected
                                ? colors.primary
                                : colors.outline.withValues(alpha: 0.48),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: colors.primary.withValues(
                                        alpha: 0.52,
                                      ),
                                      blurRadius: 7,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Выход из приложения — тем же путём, что и крестик окна.
///
/// `windowManager.close()` не убивает процесс: закрытие перехвачено, и
/// отложенные записи успевают лечь на диск, а движок загрузок — остановиться.
class _QuitButton extends StatelessWidget {
  const _QuitButton({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = L.of(context).quitApp;
    return Tooltip(
      message: label,
      child: OutlinedButton(
        key: const ValueKey('rail-quit'),
        onPressed: () => unawaited(windowManager.close()),
        style: OutlinedButton.styleFrom(
          foregroundColor: context.colors.textSecondary,
          side: BorderSide(
            color: context.colors.outline.withValues(alpha: 0.48),
          ),
          minimumSize: Size(compact ? 48 : 160, 44),
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.power_settings_new, size: 18),
            if (compact)
              SizedBox.shrink(child: ExcludeSemantics(child: Text(label))),
            if (!compact) ...[
              const SizedBox(width: 9),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppFooter extends StatelessWidget {
  const _AppFooter();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsBloc>().state;
    final gamepad = context.read<GamepadService>();
    return Container(
      height: 40,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: context.colors.railBackground.withValues(alpha: 0.84),
        border: Border(
          top: BorderSide(
            color: context.colors.outline.withValues(alpha: 0.28),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          return Row(
            children: [
              if (!compact)
                Text(
                  '© 2026 EVAPORATE',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontFamily: EvaporateTheme.monoFontFamily,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
              if (!compact) const SizedBox(width: 24),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ValueListenableBuilder<GamepadStatus>(
                    valueListenable: gamepad.status,
                    builder: (context, status, _) => ButtonHints(
                      binding: settings.gamepad,
                      gamepadConnected:
                          settings.gamepad.enabled && status.hasDevice,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              _FooterLink(
                label: 'GITHUB',
                onPressed: () => unawaited(
                  launchUrl(
                    Uri.parse('https://github.com/Hecatoncheir/evaporate'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 12,
                color: context.colors.outline.withValues(alpha: 0.5),
              ),
              _FooterLink(
                label: 'RELEASES',
                onPressed: () => unawaited(
                  launchUrl(
                    Uri.parse(
                      'https://github.com/Hecatoncheir/evaporate/releases',
                    ),
                    mode: LaunchMode.externalApplication,
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

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: context.colors.textSecondary,
      minimumSize: const Size(64, 40),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(
        fontFamily: EvaporateTheme.monoFontFamily,
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
      ),
    ),
    child: Text(label),
  );
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
