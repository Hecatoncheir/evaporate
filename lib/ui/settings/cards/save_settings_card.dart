import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/settings/settings_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/app_settings.dart';
import '../../widgets/section_card.dart';
import '../path_setting.dart';
import '../pick_folder.dart';
import '../setting_switch.dart';

/// Папка синхронизации и то, когда снимки снимаются сами.
class SaveSettingsCard extends StatelessWidget {
  const SaveSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final store = context.watch<SettingsBloc>();
    final saves = store.state.saves;
    // Карточка правит только то, что делается с сохранениями само.
    void update(SaveAutomation Function(SaveAutomation current) edit) =>
        store.add(SettingsPatched((s) => s.withSaves(edit)));

    return SectionCard(
      title: l.saves,
      icon: Icons.save_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PathSetting(
            label: l.syncFolder,
            value: saves.syncFolder ?? l.notSet,
            onPick: () => pickSettingsFolder(
              context,
              (s, dir) => s.withSaves((a) => a.copyWith(syncFolder: dir)),
            ),
            onClear: saves.syncFolder == null
                ? null
                : () => update((a) => a.copyWith(syncFolder: null)),
          ),
          const SizedBox(height: 6),
          SettingSwitch(
            value: saves.autoExportToSync,
            onChanged: (value) =>
                update((a) => a.copyWith(autoExportToSync: value)),
            title: l.copyToSyncFolder,
          ),
          const SizedBox(height: 6),
          SettingSwitch(
            value: saves.autoSnapshotOnExit,
            onChanged: (value) =>
                update((a) => a.copyWith(autoSnapshotOnExit: value)),
            title: l.snapshotOnExit,
            note: l.defaultForNewGames,
          ),
          SettingSwitch(
            value: saves.autoSnapshotOnLaunch,
            onChanged: (value) =>
                update((a) => a.copyWith(autoSnapshotOnLaunch: value)),
            title: l.snapshotOnLaunch,
            note: l.autoSnapshotOnLaunchNote,
          ),
        ],
      ),
    );
  }
}
