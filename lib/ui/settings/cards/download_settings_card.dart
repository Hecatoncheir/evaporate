import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/settings/settings_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/app_settings.dart';
import '../../theme.dart';
import '../../widgets/section_card.dart';
import '../path_setting.dart';
import '../pick_folder.dart';
import 'speed_limits_settings.dart';

/// Куда качать, сколько задач разом и какие держать скорости.
class DownloadSettingsCard extends StatelessWidget {
  const DownloadSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final store = context.watch<SettingsBloc>();
    final settings = store.state;
    void update(AppSettings Function(AppSettings current) patch) =>
        store.add(SettingsPatched(patch));

    return SectionCard(
      title: l.downloads,
      icon: Icons.download_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PathSetting(
            label: l.gamesFolder,
            value: settings.installDir,
            onPick: () => pickSettingsFolder(
              context,
              (s, dir) => s.copyWith(installDir: dir),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: EvaporateLayout.settingLabelWidth,
                child: Text(l.concurrentDownloads, style: context.text.body),
              ),
              DropdownButton<int>(
                value: settings.maxConcurrent,
                underline: const SizedBox.shrink(),
                items: [
                  for (final value in AppSettings.concurrencyOptions)
                    DropdownMenuItem(value: value, child: Text('$value')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  update((current) => current.copyWith(maxConcurrent: value));
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          const SpeedLimitsSettings(),
        ],
      ),
    );
  }
}
