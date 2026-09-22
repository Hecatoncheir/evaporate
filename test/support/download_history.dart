import 'package:evaporate/bloc/download_history/download_history_bloc.dart';
import 'package:evaporate/models/download_task.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Истории скоростей для виджета, который их показывает.
///
/// В приложении блок один на всё и кормится задачами из блока загрузок.
/// Виджет-тесту блока загрузок не нужно — довольно отдать блоку истории
/// снимок задач, какими их прислал бы движок.
Widget withHistory(Widget child, [List<DownloadTask> tasks = const []]) =>
    BlocProvider(
      create: (_) => DownloadHistoryBloc(tasks: Stream.value(tasks)),
      child: child,
    );

/// То же для одной задачи — с теми же параметрами, что были у прежнего
/// `DownloadHistoryScope`, чтобы тесты страницы не меняли вид.
Widget historyScope({required DownloadTask task, required Widget child}) =>
    withHistory(child, [task]);
