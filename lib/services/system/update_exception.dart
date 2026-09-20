/// Обновление не удалось, и человеку об этом скажут словами.
///
/// Своим файлом, потому что бросают его все трое — загрузка, распаковка и
/// установка, — и никто из них не должен ради одного исключения тянуть
/// остальных.
class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}
