import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../bloc/update/update_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../services/system/update_check.dart';
import '../theme.dart';
import '../widgets/info_row.dart';
import 'about_actions.dart';
import 'menu_entry_row.dart';
import 'setting_switch.dart';

/// Содержимое карточки «О программе»: версия, клавиши обновления, рассказ
/// о том, что сейчас происходит, и запись в меню приложений.
class AboutBody extends StatelessWidget {
  const AboutBody({super.key});

  /// Куда ведёт «Исходный код». Отсюда же человек попадает к релизам:
  /// ссылка на них у GitHub своя, и вторую клавишу она не заслуживает.
  static const repositoryUrl = 'https://github.com/Hecatoncheir/evaporate';

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final settings = context.watch<SettingsBloc>().state;
    final bloc = context.read<UpdateBloc>();

    return BlocBuilder<UpdateBloc, UpdateState>(
      builder: (context, update) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoRow(label: l.version, value: AppVersion.current),
          const SizedBox(height: 6),
          AboutActions(
            busy: update.checking,
            updating: update.installing,
            found: update.found,
            onCheck: () => bloc.add(const UpdateCheckRequested()),
            onSourceCode: () =>
                bloc.add(const UpdateLinkRequested(repositoryUrl)),
            onInstall: () => bloc.add(const UpdateInstallRequested()),
            onReleasePage: () =>
                bloc.add(UpdateLinkRequested(update.found!.url)),
          ),
          if (update.message case final message?) ...[
            const SizedBox(height: 8),
            Text(
              message,
              style: context.text.note.copyWith(
                color: update.isError
                    ? context.colors.danger
                    : context.colors.textSecondary,
              ),
            ),
          ],
          if (bloc.menuEntrySupported)
            MenuEntryRow(
              inMenu: update.inMenu ?? false,
              onToggle: () => bloc.add(const MenuEntryToggled()),
            ),
          SettingSwitch(
            value: settings.checkUpdates,
            onChanged: (value) => context.read<SettingsBloc>().add(
              SettingsChanged(settings.copyWith(checkUpdates: value)),
            ),
            title: l.checkUpdatesOnStart,
            note: l.updateNote,
          ),
        ],
      ),
    );
  }
}
