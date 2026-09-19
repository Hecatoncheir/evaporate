import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../theme.dart';

/// Куда лягут файлы снимка.
///
/// Пусто — восстанавливать некуда, и об этом говорят прямо: погасшая
/// клавиша без слова выглядела бы поломкой.
class RestoreTargetList extends StatelessWidget {
  const RestoreTargetList({super.key, required this.targets});

  /// Метка правила и путь, в который оно развернулось на этой машине.
  final Map<String, String> targets;

  @override
  Widget build(BuildContext context) {
    if (targets.isEmpty) {
      return Text(L.of(context).noTargetFolders, style: context.text.warning);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in targets.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${entry.key}: ${entry.value}',
              style: context.text.path,
            ),
          ),
      ],
    );
  }
}
