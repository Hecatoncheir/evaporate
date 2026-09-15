import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../services/notifications/notification_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

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
          SwitchListTile(
            value: enabled,
            onChanged: (value) => store.add(
              SettingsChanged(store.state.copyWith(systemNotifications: value)),
            ),
            contentPadding: EdgeInsets.zero,
            title: Text(
              l.systemNotifications,
              style: const TextStyle(fontSize: 13),
            ),
            subtitle: Text(
              l.systemNotificationsNote,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          // Система может не уметь показывать уведомления вовсе — тогда
          // включённый переключатель обещал бы то, чего не будет.
          if (!notifications.isAvailable) ...[
            const SizedBox(height: 6),
            _warning(context, l.notificationsUnavailableNote),
          ],
          const SizedBox(height: 12),
          _buttons(context, notifications, enabled: enabled),
          // Разрешение у системы просит сам человек: диалог, выскочивший
          // при первом запуске, отклоняют не глядя.
          if (Platform.isMacOS) ...[
            const SizedBox(height: 8),
            Text(
              l.permissionNote,
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

  Widget _warning(BuildContext context, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        Icons.warning_amber_rounded,
        size: 15,
        color: context.colors.warning,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: context.colors.warning,
            height: 1.4,
          ),
        ),
      ),
    ],
  );

  /// Спросить разрешение (только macOS) и отправить пробное уведомление.
  Widget _buttons(
    BuildContext context,
    NotificationService notifications, {
    required bool enabled,
  }) {
    final l = L.of(context);
    return Wrap(
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
            label: Text(l.requestPermission),
          ),
        OutlinedButton.icon(
          onPressed: enabled ? () => _sendTest(context, notifications) : null,
          icon: const Icon(Icons.send_outlined, size: 16),
          label: Text(l.test),
        ),
      ],
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
