import 'dart:io';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/notifications/notification_service.dart';
import '../feedback/snack.dart';
import '../theme.dart';

/// Спросить разрешение (только macOS) и отправить пробное уведомление.
class NotificationActions extends StatelessWidget {
  const NotificationActions({
    super.key,
    required this.notifications,
    required this.enabled,
  });

  final NotificationService notifications;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Wrap(
      spacing: EvaporateSpacing.gap,
      runSpacing: EvaporateSpacing.gap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (Platform.isMacOS)
          OutlinedButton.icon(
            onPressed: enabled ? () => _requestPermission(context) : null,
            icon: const Icon(Icons.lock_open_outlined),
            label: Text(l.requestPermission),
          ),
        OutlinedButton.icon(
          onPressed: enabled ? () => _sendTest(context) : null,
          icon: const Icon(Icons.send_outlined),
          label: Text(l.test),
        ),
      ],
    );
  }

  Future<void> _requestPermission(BuildContext context) async {
    final granted = await notifications.requestPermission();
    if (!context.mounted) return;
    if (granted) {
      showInfo(context, L.of(context).permissionGranted);
    } else {
      showError(context, L.of(context).permissionDenied);
    }
  }

  Future<void> _sendTest(BuildContext context) async {
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
