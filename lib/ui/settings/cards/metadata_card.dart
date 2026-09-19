import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/library/library_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/section_card.dart';
import '../setting_note.dart';

/// Поискать обложки и пути заново: только недостающее или всё по каждой
/// игре.
class MetadataCard extends StatelessWidget {
  const MetadataCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final library = context.read<LibraryBloc>();
    return SectionCard(
      title: l.metadataRetryTitle,
      icon: Icons.image_search_outlined,
      trailing: Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () => library.add(const MetadataRetryRequested()),
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(l.metadataRetryAction),
          ),
          OutlinedButton.icon(
            onPressed: () => library.add(const MetadataRefreshRequested()),
            icon: const Icon(Icons.autorenew, size: 16),
            label: Text(l.metadataRefreshAction),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingNote(l.metadataRetryNote),
          const SizedBox(height: 8),
          SettingNote(l.metadataRefreshNote),
        ],
      ),
    );
  }
}
