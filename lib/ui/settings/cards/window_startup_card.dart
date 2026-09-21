import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/settings/settings_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/section_card.dart';
import '../setting_switch.dart';
import '../window_start_picker.dart';

/// Каким показывается окно при запуске и запускаться ли с системой.
class WindowStartupCard extends StatelessWidget {
  const WindowStartupCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final store = context.watch<SettingsBloc>();
    final settings = store.state;

    return SectionCard(
      title: l.windowAndStartup,
      icon: Icons.desktop_windows_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WindowStartPicker(
            value: settings.windowStart,
            onChanged: (mode) => store.add(
              SettingsPatched((current) => current.copyWith(windowStart: mode)),
            ),
          ),
          const SizedBox(height: 4),
          SettingSwitch(
            value: settings.launchAtStartup,
            onChanged: (value) => store.add(
              SettingsPatched(
                (current) => current.copyWith(launchAtStartup: value),
              ),
            ),
            title: l.launchAtStartup,
            note: l.launchAtStartupNote,
          ),
        ],
      ),
    );
  }
}
