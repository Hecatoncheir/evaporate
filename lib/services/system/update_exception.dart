/// Почему обновление не удалось.
enum UpdateFailure {
  noFile,
  incomplete,
  checksumMismatch,
  serverStatus,
  noConnection,
  tooManyRedirects,
  unreadableArchive,
  escapingEntry,
  escapingLink,
  notExecutable,
  unknownLayout,
  notUpdatable,
  noWindowsSetup,
}

/// Обновление не удалось, и человеку об этом скажут словами.
///
/// Своим файлом, потому что бросают его все трое — загрузка, распаковка и
/// установка, — и никто из них не должен ради одного исключения тянуть
/// остальных.
///
/// Несёт причину, а не готовую фразу: языка там, где его бросают, нет —
/// распаковка идёт в изоляте, транспорт — статикой. Прежде фразу писали
/// по месту, и английский интерфейс получал «Сервер ответил 404». Слова
/// подбирает тот, у кого язык есть, — `describe` из `lib/l10n/labels.dart`.
///
/// Переводов в этом файле нет нарочно: они тянут Flutter, а исключение
/// бросает и распаковка, которую CI гоняет голой Dart VM
/// (`tool/rehearse_update.dart`). Когда `describe` жил здесь, сборки
/// macOS и Linux не собирали репетицию обновления, и 0.40.1 не вышла.
class UpdateException implements Exception {
  const UpdateException(this.reason, [this.detail = '']);

  final UpdateFailure reason;

  /// Что подставить в слова: код ответа, путь, ответ системы.
  final String detail;

  /// Для журнала: причина именем, без перевода.
  @override
  String toString() => detail.isEmpty
      ? 'UpdateException(${reason.name})'
      : 'UpdateException(${reason.name}: $detail)';
}
