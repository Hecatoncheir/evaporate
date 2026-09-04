import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../services/notifications/notification_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../../l10n/app_localizations.dart';

/// Раздел «Уведомления»: включение, разрешение системы и проверка.
class NotificationSettingsCard extends StatelessWidget {
  const NotificationSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SettingsBloc>();
    final notifications = context.read<NotificationService>();
    final enabled = store.state.systemNotifications;

    return SectionCard(
      title: L.of(context).notifications,
      icon: Icons.notifications_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            value: enabled,
            onChanged: (value) => store.add(
              SettingsChanged(store.state.copyWith(systemNotifications: value)),
            ),
            contentPadding: EdgeInsets.zero,
            title: Text(
              L.of(context).systemNotifications,
              style: TextStyle(fontSize: 13),
            ),
            subtitle: Text(
              L.of(context).systemNotificationsNote,
              style: TextStyle(fontSize: 12),
            ),
          ),
          if (!notifications.isAvailable) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 15,
                  color: context.colors.warning,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    L.of(context).notificationsUnavailableNote,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.warning,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (Platform.isMacOS)
                OutlinedButton.icon(
                  onPressed: enabled
                      ? () => _requestPermission(context, notifications)
                      : null,
                  icon: const Icon(Icons.lock_open_outlined, size: 16),
                  label: Text(L.of(context).requestPermission),
                ),
              OutlinedButton.icon(
                onPressed: enabled
                    ? () => _sendTest(context, notifications)
                    : null,
                icon: const Icon(Icons.send_outlined, size: 16),
                label: Text(L.of(context).test),
              ),
            ],
          ),
          if (Platform.isMacOS) ...[
            const SizedBox(height: 8),
            Text(
              L.of(context).permissionNote,
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _requestPermission(
    BuildContext context,
    NotificationService notifications,
  ) async {
    final granted = await notifications.requestPermission();
    if (!context.mounted) return;
    if (granted) {
      showInfo(context, L.of(context).permissionGranted);
    } else {
      showError(context, L.of(context).permissionDenied);
    }
  }

  Future<void> _sendTest(
    BuildContext context,
    NotificationService notifications,
  ) async {
    await notifications.show(
      AppNotification(
        title: 'Evaporate',
        body: L.of(context).testNotificationBody,
        kind: NotificationKind.test,
      ),
    );
    if (!context.mounted) return;
    showInfo(
      context,
      notifications.isAvailable
          ? L.of(context).notificationSent
          : L.of(context).notificationsUnavailable,
    );
  }
}
