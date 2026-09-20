import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/download_history/download_history_bloc.dart';
import '../../models/download_task.dart';

/// Держит историю скоростей и кормит её задачей.
///
/// Внутрь ставят и график, и показания: на странице игры они разъезжаются
/// по разным местам — график ложится подложкой под обложку с названием, а
/// показания стоят у клавиш, — но история у них обязана быть одна.
class DownloadHistoryScope extends StatefulWidget {
  const DownloadHistoryScope({
    super.key,
    required this.task,
    required this.child,
  });

  final DownloadTask task;
  final Widget child;

  @override
  State<DownloadHistoryScope> createState() => _DownloadHistoryScopeState();
}

class _DownloadHistoryScopeState extends State<DownloadHistoryScope> {
  late final DownloadHistoryBloc _history = DownloadHistoryBloc(widget.task);

  @override
  void didUpdateWidget(covariant DownloadHistoryScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _history.add(SpeedSampled(task: widget.task, previous: oldWidget.task));
  }

  @override
  void dispose() {
    unawaited(_history.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocProvider.value(value: _history, child: widget.child);
}
