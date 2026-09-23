import 'package:flutter/material.dart';

import '../../../../bloc/restore_preview/restore_preview_bloc.dart';
import '../../../../core/format.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/save_snapshot.dart';
import '../../../labels.dart';
import '../../../theme.dart';
import '../restore_options.dart';
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
    required this.options,
    required this.onOptions,
  });

  final SaveSnapshot snapshot;

  /// Куда лягут файлы и что лежит там сейчас.
  final RestorePreview preview;

  final RestoreOptions options;
  final ValueChanged<RestoreOptionsPatch> onOptions;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return SizedBox(
      width: EvaporateLayout.dialogWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.snapshotFrom(
              dateTimeLabel(L.of(context), snapshot.createdAt),
              snapshot.deviceName,
              platformLabel(snapshot.platform),
            ),
            style: context.text.prose,
          ),
          LocalFreshnessNote(preview: preview),
          const SizedBox(height: EvaporateSpacing.block),
          Text(l.filesGoHere, style: context.text.captionMuted),
          const SizedBox(height: EvaporateSpacing.tight),
          RestoreTargetList(targets: preview.targets),
          const SizedBox(height: EvaporateSpacing.field),
          RestoreOptionsForm(value: options, onChanged: onOptions),
        ],
      ),
    );
  }
}
