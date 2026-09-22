import 'dart:async';

import '../../l10n/app_localizations.dart';
import '../../services/notifications/notification_service.dart';
import '../../services/system/update_check.dart';
import 'update_bloc.dart';

/// Уведомляет о вышедшей версии — на переходе в «найдено», по разу на версию.
///
/// По переходу, а не на каждое состояние: ход загрузки обновления тоже
/// состояние, и уведомление повторялось бы на каждом проценте. Отдельной
/// функцией, а не шагом сборки приложения: сборку тесты не поднимают, а
/// повтор уведомления — ровно то, что проверять надо.
StreamSubscription<Release?> announceFoundReleases({
  required Stream<UpdateState> updates,
  required bool Function() enabled,
  required NotificationService notifications,
  required L Function() localizations,
}) => updates
    .map((state) => state.found)
    .distinct()
    .where((found) => found != null)
    .listen((release) {
      if (!enabled()) return;
      unawaited(
        notifications
            .show(
              AppNotification(
                title: localizations().newVersionOut(release!.version),
                body: localizations().updateAvailableBody,
                kind: NotificationKind.updateAvailable,
              ),
            )
            .catchError((Object _) {}),
      );
    });
