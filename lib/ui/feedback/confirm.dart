import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme.dart';

/// Спросить «да или нет» перед действием. Закрытый без ответа диалог —
/// это «нет»: необратимое не делают по умолчанию.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  // Значение по умолчанию должно быть константой, а перевод ею быть не
  // может: подставляем его внутри.
  String? confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message, style: const TextStyle(height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(L.of(context).cancel),
        ),
        FilledButton(
          style: destructive ? context.buttons.dangerFilled : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel ?? L.of(context).confirm),
        ),
      ],
    ),
  );
  return result ?? false;
}
