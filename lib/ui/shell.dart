import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/downloads/downloads_bloc.dart';
import '../bloc/library/library_bloc.dart';
import '../bloc/navigation/navigation_bloc.dart';
import '../bloc/notice.dart';
import '../bloc/saves/saves_bloc.dart';
import '../bloc/settings/settings_bloc.dart';
import '../input/gamepad_service.dart';
import '../input/input_scope.dart';
import '../models/app_settings.dart';
import 'downloads/downloads_page.dart';
import 'library/game_wave.dart';
import 'library/library_page.dart';
import 'library/primary_action.dart';
import 'saves/saves_page.dart';
import 'settings/settings_page.dart';
import 'shell/app_footer.dart';
import 'shell/top_bar.dart';
import 'theme.dart';
import 'widgets/ambient_light.dart';
import 'widgets/common.dart';
import 'widgets/fade_indexed_stack.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  /// Ниже этой ширины поля ужимаются: каждая точка нужна содержимому.
  static const _compactWidth = 980.0;

  /// Поле между краем окна и содержимым: в узком окне меньше, каждая точка
  /// ширины там нужна содержимому.
  ///
  /// Не приватное, потому что от него зависит чужое правило: полоса
  /// изменения размера у края окна не должна доставать до верхней рейки,
  /// иначе нажатие на её клавишу уйдёт в системный цикл изменения размера.
  static const compactInset = 6.0;
  static const wideInset = 10.0;

  /// Ниже этой высоты подвал убирается совсем — иначе не остаётся места
  /// самим разделам.
  static const _shortHeight = 520.0;

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
        // Сообщения об операциях приходят из блоков, а не из виджетов.
        BlocListener<LibraryBloc, LibraryState>(
          listenWhen: (a, b) => a.notice != b.notice,
          listener: (context, state) => _showNotice(context, state.notice),
        ),
        BlocListener<SavesBloc, SavesState>(
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
              builder: (context, constraints) => _layout(
                context,
                constraints,
                section: section,
                waveEnabled: waveEnabled,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Раскладка окна: обойма сверху, панель разделов, подвал.
  Widget _layout(
    BuildContext context,
    BoxConstraints constraints, {
    required int section,
    required bool waveEnabled,
  }) {
    final compact = constraints.maxWidth < _compactWidth;
    final inset = compact ? compactInset : wideInset;

    return Padding(
      padding: EdgeInsets.fromLTRB(inset, inset, inset, 0),
      child: Column(
        children: [
          ConceptTopBar(compact: compact),
          const SizedBox(height: 10),
          Expanded(
            child: _panel(context, section: section, waveEnabled: waveEnabled),
          ),
          if (constraints.maxHeight >= _shortHeight) ...[
            const SizedBox(height: 6),
            _footer(constraints.maxWidth),
          ],
        ],
      ),
    );
  }

  /// Панель, в которой живут разделы.
  ///
  /// Нарочно неплотная: под ней лежит свет выбранной игры, и заливка в упор
  /// погасила бы единственный цвет в окне.
  Widget _panel(
    BuildContext context, {
    required int section,
    required bool waveEnabled,
  }) {
    final radius = BorderRadius.circular(EvaporateTheme.radiusPanel);
    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.surface.withValues(
            alpha: HardwareSurfaceTheme.of(context).shellOpacity,
          ),
          border: Border.all(
            color: context.colors.outline.withValues(alpha: 0.45),
          ),
          borderRadius: radius,
        ),
        child: GameWave(
          key: const ValueKey('library-wave'),
          enabled: section == 0 && waveEnabled,
          child: FocusTraversalGroup(child: const _Sections()),
        ),
      ),
    );
  }

  /// Подвал идёт во всю ширину окна и потому вылезает за поля панели.
  Widget _footer(double width) => SizedBox(
    height: 40,
    child: OverflowBox(
      maxWidth: width,
      child: SizedBox(width: width, child: const AppFooter()),
    ),
  );

  static void _showNotice(BuildContext context, Notice? notice) {
    if (notice == null) return;
    if (notice.isError) {
      showError(context, notice.message);
    } else {
      showInfo(context, notice.message);
    }
  }
}

/// Четыре раздела приложения.
///
/// Лежат в стопке все разом: невидимый раздел не выброшен, а только не
/// нарисован, — переход между разделами не собирает страницу заново.
class _Sections extends StatelessWidget {
  const _Sections();

  @override
  Widget build(BuildContext context) {
    final section = context.select<NavigationBloc, int>(
      (bloc) => bloc.state.section,
    );
    final animated = context.select<SettingsBloc, bool>(
      (bloc) =>
          bloc.state.libraryEffects && bloc.state.interfaceAnimationsEnabled,
    );
    return FadeIndexedStack(
      index: section,
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
