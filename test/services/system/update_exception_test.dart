import 'package:evaporate/services/system/update_exception.dart';
import 'package:flutter_test/flutter_test.dart';

/// Журнал пишется без языка интерфейса: отказ обновления попадает туда
/// причиной и подробностью, и по строке видно, что случилось, какой бы
/// язык ни стоял у человека.
void main() {
  test('в журнал отказ идёт причиной и подробностью, без перевода', () {
    expect(
      const UpdateException(UpdateFailure.serverStatus, '404').toString(),
      'UpdateException(serverStatus: 404)',
    );
    expect(
      const UpdateException(UpdateFailure.noFile).toString(),
      'UpdateException(noFile)',
    );
  });
}
