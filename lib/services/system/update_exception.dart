import '../../l10n/app_localizations.dart';

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
/// подбирает тот, у кого язык есть, — [describe].
class UpdateException implements Exception {
  const UpdateException(this.reason, [this.detail = '']);

  final UpdateFailure reason;

  /// Что подставить в слова: код ответа, путь, ответ системы.
  final String detail;

  String describe(L l) => switch (reason) {
    UpdateFailure.noFile => l.updateNoFile,
    UpdateFailure.incomplete => l.updateIncomplete,
    UpdateFailure.checksumMismatch => l.updateChecksumMismatch,
    UpdateFailure.serverStatus => l.updateServerStatus(detail),
    UpdateFailure.noConnection => l.updateNoConnection(detail),
    UpdateFailure.tooManyRedirects => l.updateTooManyRedirects,
    UpdateFailure.unreadableArchive => l.updateArchiveUnreadable(detail),
    UpdateFailure.escapingEntry => l.updateArchiveEscapes(detail),
    UpdateFailure.escapingLink => l.updateArchiveLinkEscapes(detail),
    UpdateFailure.notExecutable => l.updateNotExecutable(detail),
    UpdateFailure.unknownLayout => l.updateUnknownLayout,
    UpdateFailure.notUpdatable => l.updateNotWritable,
    UpdateFailure.noWindowsSetup => l.updateNoWindowsSetup,
  };

  /// Для журнала: причина именем, без перевода.
  @override
  String toString() => detail.isEmpty
      ? 'UpdateException(${reason.name})'
      : 'UpdateException(${reason.name}: $detail)';
}
