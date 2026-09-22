import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/launch/executable_finder.dart';
import '../../theme.dart';

/// Что запускать: список найденных в папке игры исполняемых файлов.
///
/// Путь показан относительно папки установки, а рядом размер: у сборок с
/// лаунчером и движком имена похожи до неразличимости, и выбирают по тому,
/// где файл лежит и сколько весит.
class ExecutablePickerDialog extends StatelessWidget {
  const ExecutablePickerDialog({
    super.key,
    required this.candidates,
    required this.installDir,
  });

  final List<ExecutableCandidate> candidates;
  final String installDir;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(L.of(context).whatToRunQuestion),
      content: SizedBox(
        width: EvaporateLayout.dialogWidth,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: candidates.length,
          itemBuilder: (context, index) {
            final candidate = candidates[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.play_circle_outline, size: 18),
              title: Text(candidate.name, style: context.text.body),
              subtitle: Text(
                '${p.relative(candidate.path, from: installDir)} · '
                '${formatBytes(candidate.sizeBytes)}',
                style: context.text.small,
              ),
              onTap: () => Navigator.pop(context, candidate),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(L.of(context).cancel),
        ),
      ],
    );
  }
}
