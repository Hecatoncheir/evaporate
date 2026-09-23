import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/scan/scan_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../theme.dart';

/// Куда бросить папку и куда нажать, чтобы её выбрать.
///
/// Системное окно выбора само не открывается: человек нажал «найти игры», а
/// не «выбери папку», — поиск к этому времени уже идёт, и окно поверх него
/// было бы требованием, а не предложением. Здесь же и приём броском: папку
/// проще притащить из файлового менеджера, чем искать заново в чужом окне.
///
/// Признак «папку держат над окном» живёт здесь, как у `GameDropTarget`:
/// это не состояние, а положение мыши, и прежде он ехал сюда из окна
/// через два слоя, которым был не нужен.
class ScanDropArea extends StatefulWidget {
  const ScanDropArea({super.key, required this.onTap});

  /// Системное окно выбора — дело окна поиска, а не приёмника.
  final VoidCallback onTap;

  @override
  State<ScanDropArea> createState() => _ScanDropAreaState();
}

class _ScanDropAreaState extends State<ScanDropArea> {
  bool _dragging = false;

  void _dropped(DropDoneDetails details) {
    setState(() => _dragging = false);
    context.read<ScanBloc>().add(
      ScanFolderDropped([for (final file in details.files) file.path]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final colors = context.colors;
    final dragging = _dragging;
    final accent = dragging ? colors.primary : colors.outline;
    final wrongDrop = context.select<ScanBloc, bool>((b) => b.state.wrongDrop);

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: _dropped,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(EvaporateTheme.radiusPanel),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: EvaporateSpacing.panel,
            vertical: EvaporateSpacing.card,
          ),
          decoration: BoxDecoration(
            color: dragging ? colors.surfaceHigh : null,
            borderRadius: BorderRadius.circular(EvaporateTheme.radiusPanel),
            border: Border.all(color: accent, width: dragging ? 2 : 1),
          ),
          child: Column(
            children: [
              Icon(
                Icons.drive_folder_upload_outlined,
                size: EvaporateIconSize.large,
                color: dragging ? colors.primary : colors.textSecondary,
              ),
              const SizedBox(height: EvaporateSpacing.gap),
              Text(
                l.scanDropHere,
                textAlign: TextAlign.center,
                style: context.text.body,
              ),
              const SizedBox(height: EvaporateSpacing.hair),
              Text(
                l.scanPickFolder,
                textAlign: TextAlign.center,
                style: context.text.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              if (wrongDrop) ...[
                const SizedBox(height: EvaporateSpacing.gap),
                Text(
                  l.scanNotAFolder,
                  textAlign: TextAlign.center,
                  style: context.text.caption.copyWith(color: colors.warning),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
