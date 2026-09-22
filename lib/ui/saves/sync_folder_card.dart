import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/saves/saves_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/busy_spinner.dart';
import '../widgets/section_card.dart';
import 'sync_folder_contents.dart';
import 'sync_folder_prompt.dart';

/// Папка синхронизации: где лежат пакеты с других устройств и что с ними
/// делать.
///
/// Состояние берёт сама, а не получает от страницы: карточке нужны папка из
/// настроек и три поля из блока сохранений, и провести их сверху означало бы
/// шесть параметров, которые страница только передаёт дальше.
class SyncFolderCard extends StatelessWidget {
  const SyncFolderCard({super.key});

  @override
  Widget build(BuildContext context) {
    final folder = context.select<SettingsBloc, String?>(
      (bloc) => bloc.state.saves.syncFolder,
    );
    final scanning = context.select<SavesBloc, bool>(
      (bloc) => bloc.state.scanningSync,
    );

    return SectionCard(
      title: L.of(context).syncFolder,
      icon: Icons.sync,
      // Пока папки нет, проверять нечего — и клавиши тоже нет.
      trailing: folder == null
          ? null
          : TextButton.icon(
              onPressed: scanning
                  ? null
                  : () => context.read<SavesBloc>().add(
                      const SyncFolderScanRequested(),
                    ),
              icon: scanning
                  ? const BusySpinner()
                  : const Icon(Icons.refresh, size: 16),
              label: Text(L.of(context).check),
            ),
      child: folder == null
          ? const SyncFolderPrompt()
          : SyncFolderContents(folder: folder),
    );
  }
}
