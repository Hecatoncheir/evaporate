import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../bloc/library/library_bloc.dart';
import '../../../core/format.dart';
import '../../../core/save_path_template.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../../models/save_profile.dart';
import '../../../services/saves/save_path_finder.dart';
import '../../theme.dart';
import '../../widgets/section_card.dart';
import '../saves/auto_snapshot_toggle.dart';
import '../saves/find_paths_button.dart';
import '../saves/rule_dialog.dart';
import '../saves/rule_tile.dart';
import '../saves/suggestions_dialog.dart';
import '../saves/watched_folders.dart';

class SavePathsSection extends StatelessWidget {
  const SavePathsSection({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final rules = game.saveProfile.rules;

    return SectionCard(
      title: L.of(context).savePaths,
      icon: Icons.folder_special_outlined,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FindPathsButton(game: game, onByTitle: () => _autoDetect(context)),
          TextButton.icon(
            onPressed: () => _addRule(context),
            icon: const Icon(Icons.add, size: 16),
            label: Text(L.of(context).add),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (game.ludusaviTemplates.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(L.of(context).savedManifestPaths),
              children: [
                for (final template in game.ludusaviTemplates)
                  ListTile(title: SelectableText(template)),
              ],
            ),
          if (rules.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                L.of(context).noPathsSet,
                style: context.text.paragraph,
              ),
            )
          else ...[
            for (final rule in rules)
              RuleTile(
                rule: rule,
                gameDir: game.installDir,
                onRemove: () => _removeRule(context, rule),
              ),
          ],
          if (rules.isNotEmpty || game.ludusaviTemplates.isNotEmpty) ...[
            const SizedBox(height: 10),
            AutoSnapshotToggle(game: game),
          ],
          WatchedFolders(game: game),
        ],
      ),
    );
  }

  Future<void> _addRule(BuildContext context) async {
    final dir = await getDirectoryPath(confirmButtonText: L.of(context).choose);
    if (dir == null || !context.mounted) return;
    await _saveRule(
      context,
      template: SavePathTemplate.collapse(dir, gameDir: game.installDir),
    );
  }

  Future<void> _saveRule(
    BuildContext context, {
    required String template,
    // Значение по умолчанию обязано быть константой, а перевод ею
    // быть не может: подставляем ниже.
    String? label,
  }) async {
    final library = context.read<LibraryBloc>();
    final result = await showDialog<RuleDraft>(
      context: context,
      builder: (_) => RuleDialog(
        template: template,
        // Свободная метка — та же, что дали бы найденному пути: иначе
        // второе правило игры открывалось бы с уже занятой.
        label:
            label ??
            game.saveProfile.rulesForNewPaths([template]).firstOrNull?.label ??
            SavePathRule.defaultLabel,
        gameDir: game.installDir,
        profile: game.saveProfile,
      ),
    );
    if (result == null) return;

    final rule = SavePathRule(
      id: const Uuid().v4(),
      label: result.label,
      template: result.template,
      platform: result.currentPlatformOnly ? currentPlatformKey() : null,
    );
    library.add(SaveRulesAdded(game.id, [rule]));
  }

  void _removeRule(BuildContext context, SavePathRule rule) {
    context.read<LibraryBloc>().add(SaveRuleRemoved(game.id, rule.id));
  }

  Future<void> _autoDetect(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final suggestions = await SavePathFinder.suggest(game.title);
    if (!context.mounted) return;

    if (suggestions.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(L.of(context).noSimilarFolders)),
      );
      return;
    }

    final chosen = await showDialog<SavePathSuggestion>(
      context: context,
      builder: (_) => SuggestionsDialog(suggestions: suggestions),
    );
    if (chosen == null || !context.mounted) return;
    await _saveRule(context, template: chosen.template, label: chosen.label);
  }
}
