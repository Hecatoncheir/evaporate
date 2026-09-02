import 'dart:io';

import 'package:evaporate/services/saves/ludusavi_manifest.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Замер разбора настоящего манифеста Ludusavi.
///
/// Остальные тесты работают с синтетическим YAML на несколько записей —
/// они проверяют правильность, но ничего не говорят о цене. Настоящий
/// манифест это десятки тысяч записей, и разбор идёт в отдельном изоляте
/// именно потому, что в главном потоке он заморозил бы интерфейс. Сколько
/// именно он занимает, до сих пор никто не мерил.
///
/// Файл в репозиторий не входит: `python3 tool/fetch_manifest.py` кладёт его
/// в `third_party/ludusavi/manifest.yaml`, а без него тест пропускается.
void main() {
  final path = p.join(
    Directory.current.path,
    'third_party',
    'ludusavi',
    'manifest.yaml',
  );
  final file = File(path);
  final skip = file.existsSync()
      ? null
      : 'нет манифеста: python3 tool/fetch_manifest.py';

  test('разбор настоящего манифеста укладывается в разумное время', () {
    final source = file.readAsStringSync();
    final megabytes = source.length / (1024 * 1024);

    final watch = Stopwatch()..start();
    final manifest = LudusaviManifest.parse(source, platform: 'windows');
    watch.stop();

    // Числа печатаем: ради них тест и написан.
    // ignore: avoid_print
    print(
      'манифест ${megabytes.toStringAsFixed(1)} МБ, '
      'записей с путями: ${manifest.entries.length}, '
      'разбор: ${watch.elapsedMilliseconds} мс',
    );

    expect(
      manifest.entries.length,
      greaterThan(1000),
      reason: 'в настоящем манифесте тысячи игр — иначе разбор что-то теряет',
    );
    // Порог с запасом: разбор идёт в изоляте, и секунды там терпимы, а вот
    // десятки секунд означали бы, что подход выбран неверно.
    expect(
      watch.elapsed,
      lessThan(const Duration(seconds: 30)),
      reason: 'разбор в изоляте не должен растягиваться на десятки секунд',
    );
  }, skip: skip);

  test('сжатый индекс заметно меньше исходника', () {
    final source = file.readAsStringSync();
    final manifest = LudusaviManifest.parse(source, platform: 'windows');
    final compact = manifest.toJson().toString().length;

    // ignore: avoid_print
    print(
      'индекс: ${(compact / (1024 * 1024)).toStringAsFixed(1)} МБ '
      'против ${(source.length / (1024 * 1024)).toStringAsFixed(1)} МБ',
    );

    expect(
      compact,
      lessThan(source.length),
      reason: 'ради этого индекс и кэшируется вместо самого манифеста',
    );
  }, skip: skip);
}
