import 'package:flutter/material.dart';

import '../../../../bloc/restore_preview/restore_preview_bloc.dart';
import '../../../../core/format.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/save_snapshot.dart';
import '../../../theme.dart';
import 'local_freshness_note.dart';
import 'restore_options_form.dart';
import 'restore_target_list.dart';

/// Содержимое окна восстановления: откуда снимок, что здесь сейчас, куда
/// лягут файлы и на каких условиях.
class RestoreDialogBody extends StatelessWidget {
  const RestoreDialogBody({
    super.key,
    required this.snapshot,
    required this.preview,
    required this.backup,
    required this.wipe,
    required this.onBackup,
    required this.onWipe,
  });

  final SaveSnapshot snapshot;

  /// Куда лягут файлы и что лежит там сейчас.
  final RestorePreview preview;

  final bool backup;
  final bool wipe;
  final ValueChanged<bool> onBackup;
  final ValueChanged<bool> onWipe;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return SizedBox(
      width: 560,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.snapshotFrom(
              formatDateTime(snapshot.createdAt),
              snapshot.deviceName,
              platformLabel(snapshot.platform),
            ),
            style: context.text.prose,
          ),
          LocalFreshnessNote(preview: preview),
          const SizedBox(height: 14),
          Text(l.filesGoHere, style: context.text.captionMuted),
          const SizedBox(height: 6),
          RestoreTargetList(targets: preview.targets),
          const SizedBox(height: 12),
          RestoreOptionsForm(
            backup: backup,
            wipe: wipe,
            onBackup: onBackup,
            onWipe: onWipe,
          ),
        ],
      ),
    );
  }
}
