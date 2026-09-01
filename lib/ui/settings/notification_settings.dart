import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../bloc/settings/settings_bloc.dart';
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

    return SectionCard(
      title: 'Уведомления',
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
            title: const Text(
              'Системные уведомления',
              style: TextStyle(fontSize: 13),
            ),
            subtitle: const Text(
              'О том, что закончилось, пока окно свёрнуто: загрузка завершена '
              'или сорвалась, автоснимок сохранений не удался',
              style: TextStyle(fontSize: 12),
            ),
          ),
          if (!notifications.isAvailable) ...[
            const SizedBox(height: 6),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 15,
                  color: EvaporateTheme.warning,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Служба уведомлений недоступна — приложение работает, но '
                    'сообщать о фоновых событиях не сможет.',
                    style: TextStyle(
                      fontSize: 12,
                      color: EvaporateTheme.warning,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (Platform.isMacOS)
                OutlinedButton.icon(
                  onPressed: enabled
                      ? () => _requestPermission(context, notifications)
                      : null,
                  icon: const Icon(Icons.lock_open_outlined, size: 16),
                  label: const Text('Запросить разрешение'),
                ),
              if (Platform.isMacOS) const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: enabled
                    ? () => _sendTest(context, notifications)
                    : null,
                icon: const Icon(Icons.send_outlined, size: 16),
                label: const Text('Проверить'),
              ),
            ],
          ),
          if (Platform.isMacOS) ...[
            const SizedBox(height: 8),
            const Text(
              'macOS спрашивает разрешение один раз. Если вы его отклонили, '
              'включить уведомления можно только в системных настройках.',
              style: TextStyle(
                fontSize: 12,
                color: EvaporateTheme.textSecondary,
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
      showInfo(context, 'Разрешение получено');
    } else {
      showError(
        context,
        'Система не дала разрешение. Проверьте настройки уведомлений macOS.',
      );
    }
  }

  Future<void> _sendTest(
    BuildContext context,
    NotificationService notifications,
  ) async {
    await notifications.show(
      const AppNotification(
        title: 'Evaporate',
        body: 'Проверка: уведомления работают.',
        kind: NotificationKind.test,
      ),
    );
    if (!context.mounted) return;
    showInfo(
      context,
      notifications.isAvailable
          ? 'Уведомление отправлено'
          : 'Служба уведомлений недоступна',
    );
  }
}
