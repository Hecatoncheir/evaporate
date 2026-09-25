import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/downloads/downloads_bloc.dart';
import '../../../bloc/navigation/navigation_bloc.dart';
import '../../../bloc/settings/settings_bloc.dart';
import '../../../models/app_section.dart';
import '../../../models/library_effect.dart';
import '../../library/effects/game_wave.dart';
import '../../shell/shell_sections.dart';
import '../../shell/window_drag_area.dart';
import '../shell/ev_section.dart';
import '../shell/ev_shell.dart';
import '../sound/ev_sound.dart';
import '../sound/voices.dart';
import 'ev_app_hints_bar.dart';
import 'ev_shell_status.dart';
import 'ev_window_controls.dart';
import 'shell_commands.dart';

/// Раздел прототипа, соответствующий разделу приложения.
EvSection evSectionOf(AppSection section) =>
    EvSection.values.byName(section.name);

/// Раздел приложения по разделу прототипа; `null` — у приложения такого
/// нет (друзья, профиль).
AppSection? appSectionOf(EvSection section) =>
    AppSection.values.asNameMap()[section.name];

/// Каркас прототипа — оболочка приложения.
///
/// Раздел живёт в двух местах: в `NavigationBloc` (его листают геймпад,
/// поиск и брошенная в окно игра) и в контроллере каркаса (рейл, цифры,
/// `Ctrl+Tab`, палитра). Здесь они держатся вровень в обе стороны, и
/// каждая сторона передаёт другой только настоящую смену: иначе они
/// перебрасывались бы одним и тем же разделом без конца.
///
/// Разделы внутри — прежние страницы приложения, стопкой
/// (`ShellSections`): состояние переживает переход, а скрытый раздел
/// знает, что скрыт, — на этом стоят приёмник брошенного в окно и
/// подписки, которые молчат за спиной.
class EvAppShell extends StatefulWidget {
  const EvAppShell({super.key});

  @override
  State<EvAppShell> createState() => _EvAppShellState();
}

class _EvAppShellState extends State<EvAppShell> {
  late final EvShellController _shell = EvShellController(
    initial: evSectionOf(context.read<NavigationBloc>().state.section),
    sections: EvSection.primary,
  );
  late EvSection _heard;

  @override
  void initState() {
    super.initState();
    _heard = _shell.section;
    _shell.addListener(_onShell);
  }

  @override
  void dispose() {
    _shell
      ..removeListener(_onShell)
      ..dispose();
    super.dispose();
  }

  void _onShell() {
    final section = _shell.section;
    if (section != _heard) {
      _heard = section;
      // Смена раздела звучит, откуда бы она ни пришла: низ уходит вверх.
      EvSoundScope.maybeOf(context)?.play(EvVoice.swish);
    }
    final app = appSectionOf(section);
    final nav = context.read<NavigationBloc>();
    if (app != null && nav.state.section != app) {
      nav.add(SectionSelected(app));
    }
  }

  void _follow(AppSection section) {
    final target = evSectionOf(section);
    if (_shell.section != target) _shell.go(target);
  }

  @override
  Widget build(BuildContext context) {
    // Число на «Загрузках» — вся незаконченная работа: и та, что идёт или
    // стоит, и та, что ждёт слота. Без ждущих рейл молчал бы, пока вся
    // очередь ждёт, хотя работа есть. Ноль — не число, а его отсутствие:
    // иначе подсказка рейла говорила бы «Загрузки · 0».
    final work = context.select<DownloadsBloc, int>(
      (bloc) => bloc.state.inWork.length + bloc.state.queued.length,
    );
    return BlocListener<NavigationBloc, NavigationState>(
      listenWhen: (before, after) => before.section != after.section,
      listener: (context, state) => _follow(state.section),
      child: EvShell(
        controller: _shell,
        initials: '',
        userName: '',
        downloadsActive: work > 0 ? work : null,
        commandsOf: (context) => shellCommands(context, _shell),
        status: const [EvSpeedPill(), EvEnginePill()],
        windowControls: const EvWindowControls(),
        windowGrip: (_) => const WindowDragArea(),
        hintsBar: const EvAppHintsBar(),
        body: const _Sections(),
      ),
    );
  }
}

/// Прежние страницы приложения в месте экрана каркаса.
///
/// Каркас кладёт экран под свои полосы во всю высоту и сообщает их высоту
/// отступами. Прежние страницы об этом не знают, поэтому стоят между
/// полосами: прокрутка, догоняя фокус со стрелок и геймпада, ставит
/// выбранное к краю видимой области, и под полосой оно пряталось бы.
class _Sections extends StatelessWidget {
  const _Sections();

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final library = context.select<NavigationBloc, bool>(
      (bloc) => bloc.state.section == AppSection.library,
    );
    final waves = context.select<SettingsBloc, bool>(
      (bloc) => bloc.state.appearance.shows(LibraryEffect.waves),
    );
    return Padding(
      padding: EdgeInsets.only(top: padding.top, bottom: padding.bottom),
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        // Фокус на старте — внутри каркаса: клавиши каркаса (цифры, «/»)
        // слышит только тот, в чьей области фокус.
        child: Focus(
          autofocus: true,
          skipTraversal: true,
          child: FocusTraversalGroup(
            child: GameWave(
              key: const ValueKey('library-wave'),
              // Волна — украшение библиотеки: в других разделах её нет.
              enabled: library && waves,
              child: const ShellSections(),
            ),
          ),
        ),
      ),
    );
  }
}
