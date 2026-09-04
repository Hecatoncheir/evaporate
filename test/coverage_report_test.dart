import 'package:flutter_test/flutter_test.dart';

import '../tool/check_coverage.dart';

void main() {
  test('генерация исключается, повторные записи объединяются', () {
    final files = parseCoverage('''
SF:/checkout/lib/core/store.dart
DA:1,0
DA:2,1
end_of_record
SF:lib/core/store.dart
DA:1,1
DA:2,0
end_of_record
SF:lib/l10n/app_localizations.dart
DA:1,0
end_of_record
SF:lib/model.g.dart
DA:1,0
end_of_record
SF:lib/ui/page.dart
DA:1,0
end_of_record
''');
    final total = summarizeCoverage(files, (_) => true);
    expect(total.found, 3);
    expect(total.hit, 2);
    final core = summarizeCoverage(
      files,
      (path) => path.startsWith('lib/core/'),
    );
    expect(core.percent, 100);
  });

  test('пустой отчёт не считается полным покрытием', () {
    expect(summarizeCoverage(parseCoverage(''), (_) => true).percent, 0);
  });
}
