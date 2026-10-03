import 'package:flutter/material.dart';

import '../../ev/app/ev_library_search.dart';

/// Поиск прототипа; фокус и возврат к карточкам принадлежат странице.
class LibrarySearchField extends StatelessWidget {
  const LibrarySearchField({
    super.key,
    required this.focusNode,
    required this.onReturnToGames,
  });
  final FocusNode focusNode;
  final VoidCallback onReturnToGames;

  @override
  Widget build(BuildContext context) =>
      EvLibrarySearch(focusNode: focusNode, onReturnToGames: onReturnToGames);
}
