import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/library/library_bloc.dart';
import '../../../bloc/navigation/navigation_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/app_section.dart';
import '../../../models/game.dart';
import '../../../services/metadata/release_name.dart';
import '../../library/primary_action.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../widgets/ev_surfaces.dart';

/// Главное действие геймпада: запуск после удержания, остальные — сразу.
class EvGamepadPrimaryAction extends StatefulWidget {
  const EvGamepadPrimaryAction({super.key, required this.builder});
  final Widget Function(VoidCallback press, VoidCallback release) builder;

  @override
  State<EvGamepadPrimaryAction> createState() => _EvGamepadPrimaryActionState();
}

class _EvGamepadPrimaryActionState extends State<EvGamepadPrimaryAction>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Game? _game;
  FocusNode? _focusAtPress;
  late final _charge = AnimationController(
    vsync: this,
    duration: EvMotion.hold,
    animationBehavior: AnimationBehavior.preserve,
  )..addStatusListener(_complete);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (_game != null && primaryFocus != _focusAtPress) _release();
  }

  bool get _blocked => Navigator.of(context).canPop();

  void _press() {
    if (_game != null || _blocked) return;
    final nav = context.read<NavigationBloc>().state;
    if (nav.section != AppSection.library) return;
    final library = context.read<LibraryBloc>().state;
    final game = library.gameById(nav.selectedGameId);
    if (game == null || !canDoPrimaryAction(game)) return;
    if (primaryActionFor(game) != PrimaryAction.play) {
      dispatchPrimaryAction(context, game);
      return;
    }
    if (library.isBusy(LibraryBloc.launchKey(game.id))) return;
    _focusAtPress = primaryFocus;
    setState(() => _game = game);
    _charge.forward(from: 0);
  }

  void _release() {
    _charge.reset();
    if (_game != null) setState(() => _game = null);
  }

  void _complete(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final game = _game;
    _release();
    if (game == null || _blocked) return;
    final nav = context.read<NavigationBloc>().state;
    final library = context.read<LibraryBloc>().state;
    if (nav.section != AppSection.library ||
        nav.selectedGameId != game.id ||
        library.gameById(game.id) != game ||
        library.isBusy(LibraryBloc.launchKey(game.id))) {
      return;
    }
    dispatchPrimaryAction(context, game);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _release();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FocusManager.instance.removeListener(_focusChanged);
    _charge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<NavigationBloc, NavigationState>(
          listenWhen: (a, b) =>
              a.selectedGameId != b.selectedGameId ||
              a.openedGameId != b.openedGameId ||
              a.section != b.section ||
              a.searchFocusSeq != b.searchFocusSeq,
          listener: (_, _) => _release(),
        ),
        BlocListener<LibraryBloc, LibraryState>(
          listener: (_, state) {
            final game = _game;
            if (game != null && state.gameById(game.id) != game) _release();
          },
        ),
      ],
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.builder(_press, _release),
          if (_game case final game?)
            Positioned(
              left: 24,
              right: 24,
              bottom: 48,
              child: IgnorePointer(
                child: Center(
                  child: SizedBox(
                    width: 320,
                    child: Material(
                      type: MaterialType.transparency,
                      child: EvPanel(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              L.of(context).holdToLaunchHint,
                              style: context.ev.text.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ReleaseName.clean(game.title),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.ev.text.data,
                            ),
                            const SizedBox(height: 12),
                            AnimatedBuilder(
                              animation: _charge,
                              builder: (context, _) => LinearProgressIndicator(
                                key: const ValueKey('gamepad-launch-charge'),
                                value: _charge.value,
                                color: context.ev.colors.hot2,
                                backgroundColor: context.ev.colors.line,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
