import 'dart:async';

import 'package:evaporate/bloc/update/update_announcer.dart';
import 'package:evaporate/bloc/update/update_bloc.dart';
import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/services/notifications/notification_service.dart';
import 'package:evaporate/services/system/update_check.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/recording_notifications.dart';

/// Уведомление о новой версии — на переходе в «найдено», а не на каждом
/// состоянии блока: ход загрузки обновления тоже состояние.
void main() {
  late StreamController<UpdateState> updates;
  late RecordingNotificationService notifications;
  late bool enabled;
  late StreamSubscription<Release?> announcing;

  const release = Release(version: '9.9.9', url: 'https://example.org');

  setUp(() {
    updates = StreamController();
    notifications = RecordingNotificationService();
    enabled = true;
    announcing = announceFoundReleases(
      updates: updates.stream,
      enabled: () => enabled,
      notifications: notifications,
      localizations: LRu.new,
    );
  });

  tearDown(() async {
    await announcing.cancel();
    await updates.close();
  });

  Future<void> emit(UpdateState state) async {
    updates.add(state);
    await pumpEventQueue();
  }

  test('о найденной версии уведомляют один раз, а не на каждом шаге', () async {
    await emit(const UpdateState(checking: true));
    await emit(const UpdateState(found: release));
    await emit(const UpdateState(found: release, installing: true));
    await emit(const UpdateState(found: release, message: '42%'));

    final sent = notifications.ofKind(NotificationKind.updateAvailable);
    expect(sent, hasLength(1));
    expect(sent.single.title, contains('9.9.9'));
  });

  test('без найденного не уведомляют', () async {
    await emit(const UpdateState(checking: true));
    await emit(const UpdateState(message: 'свежая'));

    expect(notifications.sent, isEmpty);
  });

  test('выключенные уведомления молчат', () async {
    enabled = false;
    await emit(const UpdateState(found: release));

    expect(notifications.sent, isEmpty);
  });
}
