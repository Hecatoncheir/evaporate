import 'package:evaporate/models/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

/// Число одновременных загрузок из файла настроек.
///
/// Остальные числа профиля зажимаются при чтении, а это пропускали: ноль
/// останавливал очередь навсегда — ни одна загрузка не стартовала, и ни
/// слова почему, — а число мимо вариантов списка роняло сам список
/// настроек: `DropdownButton` не показывает значение, которого в нём нет.
void main() {
  AppSettings read(Object? value) =>
      AppSettings.fromJson({'maxConcurrent': value}, '/games');

  test('ноль и отрицательное не останавливают очередь', () {
    expect(read(0).maxConcurrent, AppSettings.concurrencyOptions.first);
    expect(read(-4).maxConcurrent, AppSettings.concurrencyOptions.first);
  });

  test('число мимо вариантов сводится к ближайшему из них', () {
    expect(read(4).maxConcurrent, 3);
    expect(read(7).maxConcurrent, 8);
    expect(read(1000).maxConcurrent, AppSettings.concurrencyOptions.last);
  });

  test('допустимое и отсутствующее читаются как прежде', () {
    for (final value in AppSettings.concurrencyOptions) {
      expect(read(value).maxConcurrent, value);
    }
    expect(AppSettings.fromJson(const {}, '/games').maxConcurrent, 3);
    expect(read('много').maxConcurrent, 3);
  });
}
