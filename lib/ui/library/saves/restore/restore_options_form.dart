import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../theme.dart';

/// Две галочки: снять резервную копию и стереть целевую папку до
/// распаковки.
class RestoreOptionsForm extends StatelessWidget {
  const RestoreOptionsForm({
    super.key,
    required this.backup,
    required this.wipe,
    required this.onBackup,
    required this.onWipe,
  });

  final bool backup;
  final bool wipe;
  final ValueChanged<bool> onBackup;
  final ValueChanged<bool> onWipe;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CheckboxListTile(
          value: backup,
          onChanged: (value) => onBackup(value ?? true),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(l.backupFirst, style: context.text.body),
        ),
        CheckboxListTile(
          value: wipe,
          onChanged: (value) => onWipe(value ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(l.wipeBeforeUnpack, style: context.text.body),
          subtitle: Text(l.wipeNote, style: context.text.small),
        ),
      ],
    );
  }
}
