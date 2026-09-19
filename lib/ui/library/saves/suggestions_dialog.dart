import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../l10n/app_localizations.dart';
import '../../../services/saves/save_path_finder.dart';
import '../../theme.dart';

class SuggestionsDialog extends StatelessWidget {
  const SuggestionsDialog({super.key, required this.suggestions});

  final List<SavePathSuggestion> suggestions;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(L.of(context).similarFolders),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L.of(context).foundByTitleNote,
              style: TextStyle(
                fontSize: 13,
                color: context.colors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = suggestions[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_outlined, size: 18),
                    title: Text(
                      p.basename(suggestion.path),
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      L
                          .of(context)
                          .suggestionLine(
                            suggestion.template,
                            suggestion.fileCount,
                          ),
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    onTap: () => Navigator.pop(context, suggestion),
                  );
                },
              ),
            ),
          ],
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
