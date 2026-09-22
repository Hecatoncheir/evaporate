import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../theme.dart';

/// Папки синхронизации ещё нет: объясняем, зачем она, и предлагаем выбрать.
///
/// Отдельным виджетом, а не веткой внутри карточки: у карточки два
/// непересекающихся облика, и вместе они читались бы как один длинный
/// `build` с двумя половинами, из которых всегда видна одна.
class SyncFolderPrompt extends StatelessWidget {
  const SyncFolderPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsBloc>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(L.of(context).syncFolderNote, style: context.text.paragraph),
        const SizedBox(height: EvaporateSpacing.block),
        OutlinedButton.icon(
          onPressed: () async {
            final dir = await getDirectoryPath();
            if (dir == null) return;
            settings.add(
              SettingsPatched(
                (s) => s.withSaves((s) => s.copyWith(syncFolder: dir)),
              ),
            );
          },
          icon: const Icon(Icons.folder_outlined),
          label: Text(L.of(context).chooseFolder),
        ),
      ],
    );
  }
}
