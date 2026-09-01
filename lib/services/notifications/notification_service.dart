/// Что именно произошло. Тип нужен не для текста, а для решения, показывать
/// ли уведомление вообще: часть событий пользователь видит и так.
enum NotificationKind {
  /// Загрузка завершилась — окно к этому моменту обычно свёрнуто.
  downloadFinished,

  /// Загрузка сорвалась.
  downloadFailed,

  /// Автоснимок сохранений после выхода из игры не удался. Молча терять
  /// такое нельзя: пользователь узнал бы об этом, только потеряв прогресс.
  saveFailed,

  /// Проверочное уведомление из настроек.
  test,
}

class AppNotification {
  const AppNotification({
    required this.title,
    required this.body,
    required this.kind,
  });

  final String title;
  final String body;
  final NotificationKind kind;
}

/// Системные уведомления ОС.
///
/// Абстракция нужна не ради красоты: без неё уведомления нельзя проверить
/// тестами, а плагин требует настоящей платформы.
abstract class NotificationService {
  /// Готовит плагин. Возвращает false, если уведомления недоступны —
  /// приложение обязано продолжить работать.
  Future<bool> initialize();

  /// На macOS система спрашивает разрешение у пользователя.
  Future<bool> requestPermission();

  Future<void> show(AppNotification notification);

  bool get isAvailable;
}

/// Заглушка: уведомления выключены в настройках или недоступны на платформе.
class NoopNotificationService implements NotificationService {
  const NoopNotificationService();

  @override
  bool get isAvailable => false;

  @override
  Future<bool> initialize() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> show(AppNotification notification) async {}
}
