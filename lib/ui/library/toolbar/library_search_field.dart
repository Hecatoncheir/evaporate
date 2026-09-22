import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/library_view/library_view_bloc.dart';
import '../../../input/input_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../theme.dart';
import 'toolbar_well.dart';

/// Поле поиска по библиотеке.
///
/// Вниз, Escape и Enter возвращают из него в сетку обложек: иначе,
/// спустившись сюда с клавиатуры, человек в поле и застревал.
class LibrarySearchField extends StatelessWidget {
  const LibrarySearchField({
    super.key,
    required this.focusNode,
    required this.onReturnToGames,
  });

  final FocusNode focusNode;
  final VoidCallback onReturnToGames;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('library-search'),
      width: 144,
      height: 48,
      child: ToolbarWell(
        padding: const EdgeInsets.only(
          top: EvaporateLayout.wellInset,
          right: EvaporateLayout.wellInset,
          left: EvaporateLayout.wellInset,
        ),
        child: Actions(
          actions: {
            ReturnToLibraryIntent: CallbackAction<ReturnToLibraryIntent>(
              onInvoke: (_) {
                onReturnToGames();
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
            child: TextField(
              focusNode: focusNode,
              // Запрос — прямо в блок экрана, а не колбэком через четыре
              // виджета, которым он ни к чему.
              onChanged: (value) => context.read<LibraryViewBloc>().add(
                LibraryQueryChanged(value),
              ),
              onSubmitted: (_) => onReturnToGames(),
              decoration: InputDecoration(
                hintText: L.of(context).searchHint,
                prefixIcon: const Icon(
                  Icons.search,
                  size: EvaporateIconSize.panel,
                ),
                filled: false,
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: EvaporateSpacing.field,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
