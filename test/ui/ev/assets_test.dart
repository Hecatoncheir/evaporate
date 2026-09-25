import 'dart:io';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Браузер рисует контур до первой ошибки в данных, а flutter_svg на ней
  // не рисует ничего и молчит. Так знак в рейле однажды стал пустым местом:
  // склейка строк в build_assets.py превратила «-4.8 0» в «-4.80».
  test('каждый SVG из дизайн-выгрузки разбирается', () async {
    final files =
        Directory('design/assets')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.svg'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    expect(files, hasLength(greaterThanOrEqualTo(42)));

    for (final file in files) {
      final picture = await vg.loadPicture(
        SvgStringLoader(file.readAsStringSync()),
        null,
      );
      expect(picture.size.isEmpty, isFalse, reason: file.path);
      picture.picture.dispose();
    }
  });
}
