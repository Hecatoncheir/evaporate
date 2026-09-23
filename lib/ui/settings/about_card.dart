import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../bloc/update/update_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../services/system/update_check.dart';
import '../theme.dart';
import '../widgets/info_row.dart';
import '../widgets/section_card.dart';
import 'about_actions.dart';
import 'menu_entry_row.dart';
import 'setting_switch.dart';

/// Версия приложения и проверка обновлений: версия, клавиши обновления,
/// рассказ о том, что сейчас происходит, и запись в меню приложений.
///
/// Блок обновлений берётся из приложения, а не заводится здесь: он живёт
/// всё время работы (`AppServices`), и найденное стартовой проверкой видно
/// в карточке сразу. Прежде карточка заводила свой блок, была пуста до
/// нажатия, а найденное на старте уходило только в уведомление — и при
/// выключенных уведомлениях терялось целиком.
class AboutCard extends StatelessWidget {
  const AboutCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final bloc = context.read<UpdateBloc>();
    final update = context.watch<UpdateBloc>().state;
    final checkUpdates = context.select<SettingsBloc, bool>(
      (b) => b.state.startup.checkUpdates,
    );
    return SectionCard(
      title: l.about,
      icon: Icons.info_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoRow(label: l.version, value: AppVersion.current),
          const SizedBox(height: EvaporateSpacing.tight),
          const AboutActions(),
          if (update.message case final message?) ...[
            const SizedBox(height: EvaporateSpacing.gap),
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
            value: checkUpdates,
            onChanged: (value) => context.read<SettingsBloc>().add(
              SettingsPatched(
                (current) =>
                    current.withStartup((s) => s.copyWith(checkUpdates: value)),
              ),
            ),
            title: l.checkUpdatesOnStart,
            note: l.updateNote,
          ),
        ],
      ),
    );
  }
}
