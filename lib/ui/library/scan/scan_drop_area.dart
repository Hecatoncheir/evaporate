import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../theme.dart';

/// Куда бросить папку и куда нажать, чтобы её выбрать.
///
/// Системное окно выбора само не открывается: человек нажал «найти игры», а
/// не «выбери папку», — поиск к этому времени уже идёт, и окно поверх него
/// было бы требованием, а не предложением. Здесь же и приём броском: папку
/// проще притащить из файлового менеджера, чем искать заново в чужом окне.
class ScanDropArea extends StatelessWidget {
  const ScanDropArea({
    super.key,
    required this.dragging,
    required this.wrongDrop,
    required this.onTap,
    required this.onEntered,
    required this.onExited,
    required this.onDrop,
  });

  final bool dragging;
  final bool wrongDrop;
  final VoidCallback onTap;
  final VoidCallback onEntered;
  final VoidCallback onExited;
  final void Function(DropDoneDetails) onDrop;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final colors = context.colors;
    final accent = dragging ? colors.primary : colors.outline;

    return DropTarget(
      onDragEntered: (_) => onEntered(),
      onDragExited: (_) => onExited(),
      onDragDone: onDrop,
      child: InkWell(
        onTap: onTap,
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
