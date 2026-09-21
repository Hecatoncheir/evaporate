import 'package:evaporate/core/system_folders.dart';
import 'package:flutter_test/flutter_test.dart';

/// Saved Games `path_provider` не знает, и её путь читается из вывода
/// `reg query` — разбор этого вывода и проверяется здесь, без реестра.
void main() {
  const value = SystemFolders.savedGamesValue;

  test('значение читается из вывода reg query', () {
    const output =
        '\r\n'
        r'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion'
        r'\Explorer\User Shell Folders'
        '\r\n'
        '    $value    REG_EXPAND_SZ    '
        r'%USERPROFILE%\Saved Games'
        '\r\n\r\n';

    expect(SystemFolders.regValue(output, value), r'%USERPROFILE%\Saved Games');
  });

  test('путь с пробелами и REG_SZ читается целиком', () {
    const output =
        '    $value    REG_SZ    '
        r'D:\My Games\Saved Games'
        '  \r\n';

    expect(SystemFolders.regValue(output, value), r'D:\My Games\Saved Games');
  });

  test('чужое значение за нужное не принимается', () {
    const output =
        '    Personal    REG_EXPAND_SZ    '
        r'%USERPROFILE%\Docs'
        '\r\n';

    expect(SystemFolders.regValue(output, value), isNull);
  });

  test('переменные окружения раскрываются без учёта регистра', () {
    expect(
      SystemFolders.expandWindowsVariables(
        r'%UserProfile%\Saved Games',
        environment: const {'USERPROFILE': r'C:\Users\me'},
      ),
      r'C:\Users\me\Saved Games',
    );
  });

  // Незнакомая переменная остаётся как есть — и такой путь потом не
  // берётся: лучше догадка, чем папка с `%` в имени.
  test('незнакомая переменная остаётся нераскрытой', () {
    expect(
      SystemFolders.expandWindowsVariables(
        r'%NOPE%\Saved Games',
        environment: const {},
      ),
      r'%NOPE%\Saved Games',
    );
  });
}
