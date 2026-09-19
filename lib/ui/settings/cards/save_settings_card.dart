import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/settings/settings_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/app_settings.dart';
import '../../theme.dart';
import '../../widgets/section_card.dart';
import '../path_setting.dart';
import '../pick_folder.dart';

/// Папка синхронизации и то, когда снимки снимаются сами.
class SaveSettingsCard extends StatelessWidget {
  const SaveSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final store = context.watch<SettingsBloc>();
    final settings = store.state;
    void update(AppSettings next) => store.add(SettingsChanged(next));

    return SectionCard(
      title: l.saves,
      icon: Icons.save_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PathSetting(
            label: l.syncFolder,
            value: settings.syncFolder ?? l.notSet,
            onPick: () => pickSettingsFolder(
              context,
              (s, dir) => s.copyWith(syncFolder: dir),
            ),
            onClear: settings.syncFolder == null
                ? null
                : () => update(settings.copyWith(syncFolder: null)),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            value: settings.autoExportToSync,
            onChanged: (value) =>
                update(settings.copyWith(autoExportToSync: value)),
            contentPadding: EdgeInsets.zero,
            title: Text(l.copyToSyncFolder, style: context.text.body),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            value: settings.autoSnapshotOnExit,
            onChanged: (value) =>
                update(settings.copyWith(autoSnapshotOnExit: value)),
            contentPadding: EdgeInsets.zero,
            title: Text(l.snapshotOnExit, style: context.text.body),
            subtitle: Text(l.defaultForNewGames, style: context.text.caption),
          ),
          SwitchListTile(
            value: settings.autoSnapshotOnLaunch,
            onChanged: (value) =>
                update(settings.copyWith(autoSnapshotOnLaunch: value)),
            contentPadding: EdgeInsets.zero,
            title: Text(l.snapshotOnLaunch, style: context.text.body),
            subtitle: Text(
              l.autoSnapshotOnLaunchNote,
              style: context.text.caption,
            ),
          ),
        ],
      ),
    );
  }
}
