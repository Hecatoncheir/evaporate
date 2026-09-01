import 'dart:io';

import 'package:evaporate/services/saves/ludusavi_cli.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Проверка разбора на настоящем выводе Ludusavi.
///
/// Все остальные тесты работают с синтетическими ответами, собранными по
/// документированной схеме. Здесь мы наконец сверяемся с самой программой:
/// порядок аргументов, форма JSON и поведение при незнакомой игре.
///
/// Тест пропускается, если бинарника нет или он не для этой архитектуры —
/// релиз под macOS собран только под arm64, и на Intel он не запустится.
void main() {
  final binary = _binaryPath();
  final skip = _skipReason(binary);

  late Directory config;

  setUp(() async {
    // Своя папка настроек: не трогаем ту, что может быть у пользователя.
    config = await Directory.systemTemp.createTemp('evaporate_ludusavi_');
  });

  tearDown(() async {
    try {
      if (await config.exists()) await config.delete(recursive: true);
    } on FileSystemException {
      // Остатки временной папки на результат не влияют.
    }
  });

  Future<ProcessResult> run(List<String> args) => Process.run(
    binary,
    ['--config', config.path, '--try-manifest-update', ...args],
    stdoutEncoding: systemEncoding,
    stderrEncoding: systemEncoding,
  );

  test('поиск отвечает разбираемым JSON', () async {
    final result = await run(LudusaviCli.findArgs(title: 'Celeste'));
    final output = (result.stdout as String).trim();

    // Незнакомая игра — пустой вывод и ненулевой код: это не сбой.
    if (output.isEmpty) {
      expect(result.exitCode, isNot(0));
      return;
    }

    final titles = LudusaviCli.parseFindTitles(output);
    expect(titles, isNotEmpty, reason: 'Celeste в базе Ludusavi есть');
  }, skip: skip);

  test('предпросмотр отвечает разбираемым JSON', () async {
    final found = await run(LudusaviCli.findArgs(title: 'Celeste'));
    final titles = LudusaviCli.parseFindTitles(
      (found.stdout as String).trim().isEmpty
          ? '{"games": {}}'
          : found.stdout as String,
    );
    if (titles.isEmpty) return;

    final result = await run(LudusaviCli.previewArgs(titles.first));
    final output = (result.stdout as String).trim();
    if (output.isEmpty) return;

    // Игра не установлена, поэтому путей может не быть — важно, что разбор
    // не спотыкается о настоящую форму ответа.
    final scan = LudusaviCli.parsePreview(output, title: titles.first);
    expect(scan.files, isA<List<String>>());
    expect(scan.registry, isA<List<String>>());
  }, skip: skip);

  // Обратный случай: копия есть, но эта машина её не запускает — например,
  // Intel-мак против arm64-сборки. Выбрать её нельзя ни при каких условиях.
  test('неработающая копия не выбирается', () async {
    final cli = LudusaviCli(configuredPath: () => binary);

    expect(await cli.executable(), isNot(binary));
  }, skip: skip == null ? 'копия работает — проверять нечего' : false);

  test('общие аргументы принимаются перед подкомандой', () async {
    final result = await run(const ['--help']);

    expect(
      result.exitCode,
      0,
      reason: 'иначе Ludusavi не понял наш порядок аргументов',
    );
  }, skip: skip);
}

String _binaryPath() {
  final platform = Platform.isWindows
      ? 'windows'
      : Platform.isMacOS
      ? 'macos'
      : 'linux';
  final name = Platform.isWindows ? 'ludusavi.exe' : 'ludusavi';
  return p.join(
    Directory.current.path,
    'third_party',
    'ludusavi',
    platform,
    name,
  );
}

/// Причина пропуска или null, если проверять есть чем.
Object? _skipReason(String binary) {
  if (!File(binary).existsSync()) {
    return 'нет встроенной копии: python3 tool/fetch_ludusavi.py';
  }
  try {
    final probe = Process.runSync(binary, const ['--version']);
    if (probe.exitCode != 0) return 'Ludusavi не запускается на этой машине';
  } on ProcessException catch (error) {
    // Например, релиз под macOS собран только под arm64.
    return 'Ludusavi не запускается: ${error.message}';
  }
  return null;
}
