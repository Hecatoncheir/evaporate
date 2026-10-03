import 'package:flutter/material.dart';

import '../ev/app/ev_library_toolbar.dart';

/// Панель прототипа на ресурсах страницы библиотеки.
class LibraryToolbar extends StatelessWidget {
  const LibraryToolbar({
    super.key,
    required this.searchFocus,
    required this.onScan,
    required this.onReturnToGames,
  });
  final FocusNode searchFocus;
  final VoidCallback onScan;
  final VoidCallback onReturnToGames;

  @override
  Widget build(BuildContext context) => EvLibraryToolbar(
    searchFocus: searchFocus,
    onScan: onScan,
    onReturnToGames: onReturnToGames,
  );
}
