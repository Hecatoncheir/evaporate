import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/library/library_bloc.dart';
import '../../bloc/scan/scan_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../services/launch/scan_session.dart';
import 'scan/scan_dialog_view.dart';

/// Показывает ход поиска и добавляет отмеченные игры.
///
/// Возвращает число добавленных игр.
///
/// Поиск начинается сразу, ещё до того, как человек что-то выберет: пока он
/// смотрит на найденное, известные места уже осматриваются. Сузить поиск до
/// одной папки можно здесь же — бросив её в окно или выбрав в системном
/// окне, которое откроется по нажатию.
Future<int?> showScanFolderDialog(BuildContext context, ScanSession session) {
  return showDialog<int>(
    context: context,
    // Закрывать поиск случайным нажатием мимо окна незачем: он идёт долго,
    // и начинать заново обидно.
    barrierDismissible: false,
    builder: (_) => ScanFolderDialog(session: session),
  );
}

/// Окно поиска установленных игр.
///
/// Ход обхода и отбор держит `ScanBloc`: находки приходят из `ScanSession`
/// сами, пока человек смотрит, а отбор при этом его — и переживать приход
/// новой находки он обязан. В самом окне остаётся признак «папку держат над
/// ним»: это не состояние, а положение мыши.
class ScanFolderDialog extends StatefulWidget {
  const ScanFolderDialog({super.key, required this.session});

  final ScanSession session;

  @override
  State<ScanFolderDialog> createState() => _ScanFolderDialogState();
}

class _ScanFolderDialogState extends State<ScanFolderDialog> {
  bool _dragging = false;

  Future<void> _pickFolder(ScanBloc scan) async {
    final directory = await getDirectoryPath(
      confirmButtonText: L.of(context).scan,
    );
    if (directory != null) scan.add(ScanNarrowed(directory));
  }

  void _add(BuildContext context, ScanState scan) {
    context.read<LibraryBloc>().add(ScannedGamesAdded(scan.selected));
    Navigator.pop(context, scan.selected.length);
  }

  @override
  Widget build(BuildContext context) {
    // Esc закрывает окно, как и кнопка B геймпада. `barrierDismissible:
    // false` выключил вместе с нажатием мимо окна и Esc, а закрывать долгий
    // поиск должно мешать только случайное нажатие, а не клавиша выхода.
    return Actions(
      actions: {
        DismissIntent: CallbackAction<DismissIntent>(
          onInvoke: (_) {
            Navigator.maybePop(context);
            return null;
          },
        ),
      },
      // Фокус — в само окно: иначе в нём не сфокусировано ничего, и Esc
      // уходил в библиотеку под ним. Обход этот узел пропускает.
      child: Focus(
        autofocus: true,
        skipTraversal: true,
        child: BlocProvider(
          create: (context) => ScanBloc(widget.session),
          child: BlocBuilder<ScanBloc, ScanState>(
            builder: (context, scan) => ScanDialogView(
              session: widget.session,
              scan: scan,
              dragging: _dragging,
              onDragging: (value) => setState(() => _dragging = value),
              onPickFolder: () => _pickFolder(context.read<ScanBloc>()),
              onAdd: () => _add(context, scan),
            ),
          ),
        ),
      ),
    );
  }
}
