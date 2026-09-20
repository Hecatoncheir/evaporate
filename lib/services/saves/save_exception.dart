/// Со снимком не вышло, и человеку об этом скажут словами.
///
/// Своим файлом, потому что бросают его все, кто работает с сейвами:
/// менеджер снимков, разбор пакета, раскладка файлов.
class SaveException implements Exception {
  SaveException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Сохранений нет вовсе — снимать нечего.
///
/// Отдельный тип, потому что это не беда, а обычный исход: игра, в которую
/// ещё не играли, и массовая выгрузка такие просто пропускает.
class SaveNothingFoundException extends SaveException {
  SaveNothingFoundException(super.message);
}
