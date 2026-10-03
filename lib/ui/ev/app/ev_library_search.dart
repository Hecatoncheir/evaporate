import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/library_view/library_view_bloc.dart';
import '../../../input/input_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../widgets/ev_controls.dart';
import '../widgets/ev_icon.dart';

/// Поле прототипа на запросе библиотеки; фокус принадлежит странице.
class EvLibrarySearch extends StatefulWidget {
  const EvLibrarySearch({
    super.key,
    required this.focusNode,
    required this.onReturnToGames,
  });
  final FocusNode focusNode;
  final VoidCallback onReturnToGames;

  @override
  State<EvLibrarySearch> createState() => _EvLibrarySearchState();
}

class _EvLibrarySearchState extends State<EvLibrarySearch> {
  late final _text = TextEditingController(
    text: context.read<LibraryViewBloc>().state.query,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _query(String value) =>
      context.read<LibraryViewBloc>().add(LibraryQueryChanged(value));

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final l = L.of(context);
    return BlocListener<LibraryViewBloc, LibraryView>(
      listenWhen: (before, after) => before.query != after.query,
      listener: (context, view) {
        if (_text.text == view.query) return;
        _text.value = TextEditingValue(
          text: view.query,
          selection: TextSelection.collapsed(offset: view.query.length),
        );
      },
      child: ListenableBuilder(
        listenable: Listenable.merge([widget.focusNode, _text]),
        builder: (context, child) => AnimatedContainer(
          key: const ValueKey('library-search'),
          duration: EvMotion.fast,
          curve: EvMotion.ease,
          width: 280,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: ev.radii.b2,
            color: c.ink.withValues(alpha: .025),
            border: Border.all(
              color: widget.focusNode.hasFocus
                  ? c.hot1.withValues(alpha: .5)
                  : c.line,
            ),
            boxShadow: widget.focusNode.hasFocus
                ? [
                    BoxShadow(
                      color: c.hot1.withValues(alpha: .16),
                      blurRadius: 20,
                    ),
                  ]
                : null,
          ),
          child: Actions(
            actions: {
              ReturnToLibraryIntent: CallbackAction<ReturnToLibraryIntent>(
                onInvoke: (_) {
                  widget.onReturnToGames();
                  return null;
                },
              ),
            },
            child: Shortcuts(
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.arrowDown):
                    ReturnToLibraryIntent(),
                SingleActivator(LogicalKeyboardKey.escape):
                    ReturnToLibraryIntent(),
                SingleActivator(LogicalKeyboardKey.enter):
                    ReturnToLibraryIntent(),
                SingleActivator(LogicalKeyboardKey.numpadEnter):
                    ReturnToLibraryIntent(),
              },
              child: Row(
                children: [
                  EvIcon(EvIcons.search, size: 15, color: c.ink4),
                  const SizedBox(width: 9),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      focusNode: widget.focusNode,
                      onChanged: _query,
                      onSubmitted: (_) => widget.onReturnToGames(),
                      autocorrect: false,
                      enableSuggestions: false,
                      cursorColor: c.hot2,
                      style: ev.text.body.copyWith(fontSize: 13, color: c.ink),
                      decoration:
                          InputDecoration.collapsed(
                            hintText: l.searchHint,
                            hintStyle: ev.text.body.copyWith(
                              fontSize: 13,
                              color: c.ink4,
                            ),
                          ).copyWith(
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                          ),
                    ),
                  ),
                  if (_text.text.isNotEmpty)
                    EvGhostButton.icon(
                      label: l.libraryClearSearch,
                      icon: EvIcons.close,
                      height: 28,
                      onPressed: () {
                        _text.clear();
                        _query('');
                        widget.focusNode.requestFocus();
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
