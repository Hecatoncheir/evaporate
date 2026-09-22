import 'package:evaporate/l10n/app_localizations_en.dart';
import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/ui/labels.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Числа, даты и размеры в интерфейсе — по правилам его языка.
///
/// Прежде их показывали журнальные функции ядра: «1.5 GB» и «22.09.2026»
/// в любом интерфейсе, хотя подпись скорости обещала «1,2 МБ».
void main() {
  // В приложении данные дат загружает делегат `GlobalMaterialLocalizations`;
  // здесь его нет.
  setUpAll(initializeDateFormatting);

  test('размер — дробью и единицами своего языка', () {
    const bytes = 1.5 * 1024 * 1024 * 1024;

    expect(bytesLabel(LRu(), bytes), '1,5 ГБ');
    expect(bytesLabel(LEn(), bytes), '1.5 GB');
    expect(bytesLabel(LRu(), 512), '512 Б');
    expect(bytesLabel(LEn(), 0), '0 B');
  });

  test('скорость собирается из размера того же языка', () {
    expect(speedLabel(LRu(), 1536 * 1024), contains('1,5 МБ'));
    expect(speedLabel(LEn(), 1536 * 1024), contains('1.5 MB'));
  });

  test('дата — в порядке своего языка', () {
    final moment = DateTime(2026, 9, 22, 14, 5);

    expect(dateTimeLabel(LRu(), moment), '22.09.2026 14:05');
    expect(dateTimeLabel(LEn(), moment), '9/22/2026 14:05');
  });

  test('разряды — разделителем своего языка', () {
    // Русский разделяет разряды неразрывным пробелом, английский — запятой.
    expect(countLabel(LRu(), 222495), '222 495');
    expect(countLabel(LEn(), 222495), '222,495');
  });
}
