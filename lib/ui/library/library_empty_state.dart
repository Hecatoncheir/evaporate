import 'package:flutter/material.dart';

import '../ev/app/ev_library_empty.dart';

/// Пустое состояние прототипа с действиями настоящей библиотеки.
class LibraryEmptyState extends StatelessWidget {
  const LibraryEmptyState({super.key, required this.onScan});
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) => EvLibraryEmptyState(onScan: onScan);
}
