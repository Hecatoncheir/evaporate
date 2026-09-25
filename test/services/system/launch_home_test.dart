import 'package:evaporate/services/system/launch_home.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('дом берётся из --home=<папка>', () {
    expect(launchHome(['--home=/tmp/copy']), '/tmp/copy');
    expect(launchHome(['--smoke', r'--home=C:\data copy']), r'C:\data copy');
  });

  test('без флага дома нет — данные в системной папке', () {
    expect(launchHome(const []), isNull);
    expect(launchHome(['--smoke']), isNull);
  });

  // Пустое значение положило бы данные в текущий каталог, а флаг без
  // знака равенства — не наш формат: гадать, что имели в виду, незачем.
  test('пустой или неполный флаг — не дом', () {
    expect(launchHome(['--home=']), isNull);
    expect(launchHome(['--home', '/tmp/copy']), isNull);
  });

  test('из двух флагов берётся первый', () {
    expect(launchHome(['--home=/a', '--home=/b']), '/a');
  });
}
