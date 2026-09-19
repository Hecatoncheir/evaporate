import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Как поступить с играми, где здешние сохранения новее пакета.
///
/// Отвечает `true` — перезаписать, `false` — пропустить, `null` — загрузку
/// отменили. Два действия вместо галочки намеренно: это выбор, а не
/// настройка, и человек должен сделать его осознанно в тот момент, когда он
/// что-то значит.
class ImportNewerDialog extends StatelessWidget {
  const ImportNewerDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return AlertDialog(
      title: Text(l.importAllQuestion),
      content: Text(l.importAllNote),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.importOverwriteNewer),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.importSkipNewer),
        ),
      ],
    );
  }
}
