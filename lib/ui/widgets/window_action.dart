import 'dart:async';

import 'package:flutter/material.dart';

import '../feedback/snack.dart';

/// Выполняет действие над окном и говорит, если система откажет.
///
/// Гасить отказ нельзя: не свернувшееся по нажатию окно выглядит зависшим,
/// а объяснить, что случилось, кроме нас некому.
Future<void> runWindowAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } on Object catch (error) {
    if (context.mounted) showError(context, error);
  }
}
