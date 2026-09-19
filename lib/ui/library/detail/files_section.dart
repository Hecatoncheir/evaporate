import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../../bloc/library/library_bloc.dart';
import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../../services/launch/executable_finder.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class FilesSection extends StatelessWidget {
  const FilesSection({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: L.of(context).gameFiles,
      icon: Icons.folder_outlined,
      child: Column(
        children: [
          InfoRow(
            label: L.of(context).installFolder,
            value: game.installDir ?? L.of(context).notSet,
            monospace: game.installDir != null,
            valueColor: game.installDir == null
                ? context.colors.textSecondary
                : null,
          ),
          InfoRow(
            label: L.of(context).whatToRun,
            value: game.executablePath ?? L.of(context).notChosen,
            monospace: game.executablePath != null,
            valueColor: game.executablePath == null
                ? context.colors.textSecondary
                : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickExecutable(context),
                icon: const Icon(Icons.description_outlined, size: 16),
                label: Text(L.of(context).chooseFile),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: game.installDir == null
                    ? null
                    : () => _autoDetect(context),
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: Text(L.of(context).findAutomatically),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickExecutable(BuildContext context) async {
    final library = context.read<LibraryBloc>();
    final file = await openFile();
    if (file == null) return;
    library.add(GameExecutableSet(game.id, file.path));
  }

  Future<void> _autoDetect(BuildContext context) async {
    final library = context.read<LibraryBloc>();
    final dir = game.installDir;
    if (dir == null) return;

    final candidates = await ExecutableFinder.scan(dir);
    if (!context.mounted) return;
    if (candidates.isEmpty) {
      showError(context, L.of(context).noExecutablesFound);
      return;
    }

    final chosen = await showDialog<ExecutableCandidate>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(L.of(context).whatToRunQuestion),
        content: SizedBox(
          width: 560,
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
                  '${p.relative(candidate.path, from: dir)} · '
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
      ),
    );
    if (chosen == null) return;
    library.add(GameExecutableSet(game.id, chosen.path));
  }
}
