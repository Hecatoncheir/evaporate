import 'package:flutter/material.dart';

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
    required this.targets,
    required this.backup,
    required this.wipe,
    required this.onBackup,
    required this.onWipe,
  });

  final SaveSnapshot snapshot;

  /// Метка правила и путь, в который оно развернулось на этой машине.
  final Map<String, String> targets;

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
          LocalFreshnessNote(snapshotAt: snapshot.createdAt),
          const SizedBox(height: 14),
          Text(l.filesGoHere, style: context.text.captionMuted),
          const SizedBox(height: 6),
          RestoreTargetList(targets: targets),
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
