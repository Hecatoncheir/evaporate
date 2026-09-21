import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../services/notifications/notification_service.dart';
import '../widgets/inline_warning.dart';
import '../widgets/section_card.dart';
import 'notification_actions.dart';
import 'setting_note.dart';
import 'setting_switch.dart';

/// Раздел «Уведомления»: включение, разрешение системы и проверка.
class NotificationSettingsCard extends StatelessWidget {
  const NotificationSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SettingsBloc>();
    final notifications = context.read<NotificationService>();
    final enabled = store.state.systemNotifications;
    final l = L.of(context);

    return SectionCard(
      title: l.notifications,
      icon: Icons.notifications_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingSwitch(
            value: enabled,
            onChanged: (value) => store.add(
              SettingsPatched(
                (current) => current.copyWith(systemNotifications: value),
              ),
            ),
            title: l.systemNotifications,
            note: l.systemNotificationsNote,
          ),
          // Система может не уметь показывать уведомления вовсе — тогда
          // включённый переключатель обещал бы то, чего не будет.
          if (!notifications.isAvailable) ...[
            const SizedBox(height: 6),
            InlineWarning(l.notificationsUnavailableNote),
          ],
          const SizedBox(height: 12),
          NotificationActions(notifications: notifications, enabled: enabled),
          // Разрешение у системы просит сам человек: диалог, выскочивший
          // при первом запуске, отклоняют не глядя.
          if (Platform.isMacOS) ...[
            const SizedBox(height: 8),
            SettingNote(l.permissionNote),
          ],
        ],
      ),
    );
  }
}
