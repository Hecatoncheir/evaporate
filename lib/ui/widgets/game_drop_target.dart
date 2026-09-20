import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/library/library_bloc.dart';
import '../library/drop_overlay.dart';

/// Приёмник сброшенных в окно файлов.
///
/// Здесь остаётся только приём: чем оказалось сброшенное и что с ним
/// делать, решает `LibraryBloc` по событию `FilesDropped`. У виджета нет
/// ни журнала, ни `Notice`, а разбор умеет не смочь.
///
/// Один виджет на оба экрана, где это уместно. Библиотека и загрузки
/// принимают одно и то же, и расходиться им незачем: человек бросает файл
/// туда, где сейчас смотрит, а не туда, где по нашему замыслу полагается.
///
/// Magnet-ссылку сюда не притащить, и это не недоделка: `desktop_drop`
/// читает на macOS только file-URL, на Windows — только `CF_HDROP`, а
/// ссылка из браузера приходит как `public.url` и до приложения не
/// доезжает. Её вставляют в «Добавить игру».
class GameDropTarget extends StatefulWidget {
  const GameDropTarget({
    super.key,
    required this.child,
    this.enabled = true,
    this.selectAfterDrop = true,
  });

  final Widget child;

  /// Пока открыто системное окно выбора папки, брошенное принадлежит ему.
  final bool enabled;

  /// Подсветить добавленную игру в сетке библиотеки.
  ///
  /// Страницу это не открывает — за неё отвечает `GameOpened`, — но
  /// витрина следует за выбором, и в библиотеке так и нужно: иначе
  /// брошенная игра затеряется среди прочих. С экрана загрузок выбор в
  /// соседнем разделе не трогаем: человек его там оставил, а увиденное им
  /// сейчас — очередь, и она пополнится сама.
  final bool selectAfterDrop;

  @override
  State<GameDropTarget> createState() => _GameDropTargetState();
}

class _GameDropTargetState extends State<GameDropTarget> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    // Разделы живут в `IndexedStack` все разом — невидимый не выброшен, а
    // только не нарисован, — и приёмник на каждом из них ловил бы один и
    // тот же сброс. Один файл добавлялся бы дважды.
    //
    // Отличаем видимый по `TickerMode`: `FadeIndexedStack` включает его
    // ровно текущему разделу. Тот же признак слушают украшения, чтобы не
    // жечь батарею за спиной, — заводить второй незачем.
    final visible = TickerMode.valuesOf(context).enabled && widget.enabled;

    return DropTarget(
      onDragEntered: (_) {
        if (visible) setState(() => _dragging = true);
      },
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) {
        setState(() => _dragging = false);
        if (!visible || details.files.isEmpty) return;
        context.read<LibraryBloc>().add(
          FilesDropped([
            for (final file in details.files) file.path,
          ], select: widget.selectAfterDrop),
        );
      },
      child: Stack(
        children: [
          Positioned.fill(child: widget.child),
          if (_dragging) const Positioned.fill(child: DropOverlay()),
        ],
      ),
    );
  }
}
