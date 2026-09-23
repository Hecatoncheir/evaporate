import 'package:evaporate/core/home_dir.dart';
import 'package:flutter_test/flutter_test.dart';

/// Домашнюю папку угадывают в одном месте: две догадки уже расходились, и
/// корни поиска игр с корнями шаблонов сохранений смотрели в разные папки.
void main() {
  test('на Windows дом — USERPROFILE', () {
    final home = homeDirIn(const {
      'USERPROFILE': r'C:\Users\me',
      'HOMEDRIVE': 'D:',
      'HOMEPATH': r'\Other',
    }, windows: true);

    expect(home, r'C:\Users\me');
  });

  // `HOMEPATH` — путь без диска: взятый один, он указывал бы на тот диск,
  // что окажется текущим. Так его и брала одна из двух прежних догадок, а
  // другая без USERPROFILE отвечала корнем диска.
  test('без USERPROFILE — диск и путь вместе, а не путь без диска', () {
    final home = homeDirIn(const {
      'HOMEDRIVE': 'D:',
      'HOMEPATH': r'\Users\me',
    }, windows: true);

    expect(home, r'D:\Users\me');
  });

  test('пустое значение — не папка', () {
    final home = homeDirIn(const {
      'USERPROFILE': '',
      'HOMEDRIVE': 'C:',
      'HOMEPATH': r'\Users\me',
    }, windows: true);

    expect(home, r'C:\Users\me');
  });

  test('окружение, не назвавшее дома, так и говорит', () {
    expect(homeDirIn(const {'HOMEPATH': r'\Users\me'}, windows: true), isNull);
    expect(homeDirIn(const {'USERPROFILE': r'C:\x'}, windows: false), isNull);
  });

  test('вне Windows дом — HOME', () {
    final home = homeDirIn(const {
      'HOME': '/home/me',
      'USERPROFILE': r'C:\Users\me',
    }, windows: false);

    expect(home, '/home/me');
  });
}
