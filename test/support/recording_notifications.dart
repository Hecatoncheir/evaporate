import 'package:evaporate/services/notifications/notification_service.dart';

/// Запоминает отправленные уведомления вместо показа их системой.
class RecordingNotificationService implements NotificationService {
  RecordingNotificationService({this.available = true});

  final bool available;
  final List<AppNotification> sent = [];
  int permissionRequests = 0;

  @override
  bool get isAvailable => available;

  @override
  Future<bool> initialize() async => available;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return available;
  }

  @override
  Future<void> show(AppNotification notification) async {
    sent.add(notification);
  }

  List<AppNotification> ofKind(NotificationKind kind) =>
      sent.where((n) => n.kind == kind).toList();
}
