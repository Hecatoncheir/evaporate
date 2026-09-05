import 'dart:io';

import 'package:evaporate/services/launch/windows_installs.dart';
import 'package:flutter_test/flutter_test.dart';

/// Игры, поставленные обычным установщиком мимо всяких лончеров, иначе не
/// найти: в папках Steam и GOG их нет. Установщик записывает
/// `InstallLocation` — это единственный их след.
///
/// Источник слабый: в тех же ветках лежит вообще всё установленное. Отбор
/// проверяется тут же, потому что без него в библиотеку поехали бы браузеры.
void main() {
  /// Вывод `reg query ... /s` в том виде, в каком его печатает Windows.
  String dump(List<Map<String, String>> entries) {
    final buffer = StringBuffer();
    for (var i = 0; i < entries.length; i++) {
      buffer.writeln(
        r'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion'
        r'\Uninstall\Запись$i',
      );
      entries[i].forEach((name, value) {
        buffer.writeln('    $name    REG_SZ    $value');
      });
      buffer.writeln();
    }
    return buffer.toString();
  }

  /// Подделка `reg`: отвечает готовым выводом на первую ветку и пустотой
  /// на остальные.
  Future<ProcessResult> Function(String, List<String>) reg(String output) {
    var call = 0;
    return (executable, args) async =>
        ProcessResult(0, 0, call++ == 0 ? output : '', '');
  }

  test('запись с папкой установки читается', () async {
    final found = await WindowsInstalls.installed(
      checkExists: false,
      run: reg(
        dump([
          {
            'DisplayName': 'Тихая гавань',
            'InstallLocation': r'C:\Games\Тихая гавань',
            'Publisher': 'Небольшая студия',
          },
        ]),
      ),
    );

    expect(found, hasLength(1));
    expect(found.single.name, 'Тихая гавань');
    expect(found.single.installDir, r'C:\Games\Тихая гавань');
  });

  // Пробелы есть и в названии, и в пути: резать строку по одному пробелу
  // нельзя, разделитель — несколько подряд.
  test('пробелы в названии и пути не ломают разбор', () async {
    final found = await WindowsInstalls.installed(
      checkExists: false,
      run: reg(
        dump([
          {
            'DisplayName': 'Игра с длинным названием',
            'InstallLocation': r'C:\Program Files\Моя студия\Игра',
          },
        ]),
      ),
    );

    expect(found.single.name, 'Игра с длинным названием');
    expect(found.single.installDir, r'C:\Program Files\Моя студия\Игра');
  });

  test('запись без папки установки пропускается', () async {
    final found = await WindowsInstalls.installed(
      checkExists: false,
      run: reg(
        dump([
          {'DisplayName': 'Без папки', 'InstallLocation': ''},
          {'DisplayName': 'Совсем без значения'},
        ]),
      ),
    );

    expect(found, isEmpty);
  });

  // Без этого в библиотеку поехали бы драйверы и распространяемые пакеты.
  test('системные места и издатели отсеиваются', () async {
    final found = await WindowsInstalls.installed(
      checkExists: false,
      run: reg(
        dump([
          {
            'DisplayName': 'Драйвер',
            'InstallLocation': r'C:\Windows\System32\Драйвер',
          },
          {
            'DisplayName': 'Библиотека',
            'InstallLocation': r'C:\Program Files\Common Files\Штука',
          },
          {
            'DisplayName': 'Панель управления',
            'InstallLocation': r'C:\Games\Панель',
            'Publisher': 'NVIDIA Corporation',
          },
          {
            'DisplayName': 'Настоящая игра',
            'InstallLocation': r'C:\Games\Настоящая',
          },
        ]),
      ),
    );

    expect(found.map((e) => e.name), ['Настоящая игра']);
  });

  test('служебные записи и обновления Windows пропускаются', () async {
    final found = await WindowsInstalls.installed(
      checkExists: false,
      run: reg(
        dump([
          {
            'DisplayName': 'Скрытая',
            'InstallLocation': r'C:\Games\Скрытая',
            'SystemComponent': '0x1',
          },
          {
            'DisplayName': 'KB5031234',
            'InstallLocation': r'C:\Games\Обновление',
          },
        ]),
      ),
    );

    expect(found, isEmpty);
  });

  test('одна и та же папка из двух веток не двоится', () async {
    var call = 0;
    final output = dump([
      {'DisplayName': 'Игра', 'InstallLocation': r'C:\Games\Игра'},
    ]);

    final found = await WindowsInstalls.installed(
      checkExists: false,
      // Одна и та же запись видна и в HKLM, и в WOW6432Node.
      run: (executable, args) async =>
          ProcessResult(0, 0, call++ < 2 ? output : '', ''),
    );

    expect(found, hasLength(1));
  });

  test('недоступная ветка не роняет чтение', () async {
    final found = await WindowsInstalls.installed(
      checkExists: false,
      run: (executable, args) async => ProcessResult(0, 1, '', 'Отказано'),
    );

    expect(found, isEmpty);
  });

  test('отсутствие reg не роняет чтение', () async {
    final found = await WindowsInstalls.installed(
      checkExists: false,
      run: (executable, args) async =>
          throw ProcessException(executable, args, 'нет такой команды'),
    );

    expect(found, isEmpty);
  });

  test('на не-Windows реестр не спрашивается вовсе', () async {
    expect(
      await WindowsInstalls.installed(),
      Platform.isWindows ? isNotNull : isEmpty,
    );
  });
}
