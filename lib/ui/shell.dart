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
import '../models/app_section.dart';
import '../models/app_settings.dart';
import '../models/library_effect.dart';
import 'feedback/snack.dart';
import 'library/primary_action.dart';
import 'shell/shell_layout.dart';
import 'theme.dart';
import 'widgets/ambient_light.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  /// Действие кнопки X: сделать с выбранной игрой то же, что делает
  /// главная кнопка её карточки. Решение о том, что это за действие, —
  /// общее (`primary_action.dart`), иначе геймпад и кадр библиотеки
  /// однажды разошлись бы на одном состоянии игры.
  void _primaryAction(BuildContext context) {
    final nav = context.read<NavigationBloc>();
    if (nav.state.section != AppSection.library) return;

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
    final ambientEnabled = context.select<SettingsBloc, bool>(
      (bloc) => bloc.state.appearance.shows(LibraryEffect.ambient),
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
            child: const ShellLayout(),
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
