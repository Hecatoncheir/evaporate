import 'package:evaporate/models/proxy_settings.dart';
import 'package:flutter_test/flutter_test.dart';

/// Настройки прокси, записанные прежними версиями.
void main() {
  // `bypass` остался от aria2 (`--no-proxy`) и никем не читался: ни
  // перехват `HttpClient`, ни движок загрузок обходов не знают. Поле
  // убрано, но файлы настроек с ним лежат у людей на дисках.
  test('файл с ключом времён aria2 читается, а ключ не возвращается', () {
    final settings = ProxySettings.fromJson(const {
      'enabled': true,
      'kind': 'socks5',
      'host': '127.0.0.1',
      'port': 9050,
      'bypass': ['localhost'],
    });

    expect(settings.isUsable, isTrue);
    expect(settings.port, 9050);
    expect(settings.toJson().containsKey('bypass'), isFalse);
  });
}
