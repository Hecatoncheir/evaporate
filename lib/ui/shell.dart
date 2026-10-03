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
import 'ev/app/ev_app_shell.dart';
import 'ev/app/ev_gamepad_primary_action.dart';
import 'feedback/snack.dart';
import 'widgets/pointer_trail.dart';

/// Оболочка окна: сообщения блоков, раскладка геймпада и общий слой ввода
/// вокруг каркаса прототипа ([EvAppShell]).
///
/// Каркас — облик, а это — поведение, которое у приложения было до него и
/// остаётся при любом облике: клавиатура и геймпад сводятся к одним
/// действиям, сообщения об операциях показывает одно место.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

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
      child: EvGamepadPrimaryAction(
        builder: (press, release) => InputScope(
          gamepad: gamepad,
          onSectionChange: (delta) => nav.add(SectionCycled(delta)),
          onPrimaryAction: press,
          onPrimaryRelease: release,
          onSearch: () => nav.add(const SearchFocusRequested()),
          onBack: nav.closeOpenedGame,
          // Курсор ловится над всей оболочкой, а не над каждым украшением:
          // он один на всех и сглажен одними часами. Волна тянется за
          // сглаженным, частицы берут сырое положение — отвечают на руку
          // сразу.
          child: const PointerTrailScope(child: EvAppShell()),
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
