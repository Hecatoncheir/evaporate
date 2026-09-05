import 'dart:io';

import 'package:evaporate/services/launch/game_roots.dart';
import 'package:evaporate/services/launch/scan_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Обход дисков идёт секундами, а то и дольше. Пока он идёт, человеку надо
/// показывать, на чём приложение стоит, и уметь его прервать: выбор папки в
/// системном окне отменяет начатый заход, а не встаёт за ним в очередь.
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_session_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// Папка с исполняемым файлом внутри — то, что сканер считает игрой.
  Future<Directory> gameDir(String root, String name) async {
    final dir = Directory(p.join(tmp.path, root, name));
    await dir.create(recursive: true);
    final file = File(
      p.join(dir.path, Platform.isWindows ? 'game.exe' : 'game'),
    );
    await file.writeAsString('исполняемый');
    if (!Platform.isWindows) await Process.run('chmod', ['+x', file.path]);
    return dir;
  }

  ScanSession sessionOver(
    List<String> roots, {
    Set<String> existing = const {},
  }) {
    final session = ScanSession(
      existingDirs: existing,
      steamRoots: const [],
      fixedRoots: [
        for (final root in roots)
          GameRoot(path: p.join(tmp.path, root), kind: GameRootKind.games),
      ],
    );
    addTearDown(session.dispose);
    return session;
  }

  test('известные места осматриваются без выбора папки', () async {
    await gameDir('Первое место', 'Альфа');
    await gameDir('Второе место', 'Бета');
    final session = sessionOver(['Первое место', 'Второе место']);

    await session.scanKnownRoots();

    expect(session.found.map((g) => g.title), ['Альфа', 'Бета']);
    expect(session.isRunning, isFalse);
    expect(session.isComplete, isTrue);
  });

  test('ход сообщается по мере обхода', () async {
    await gameDir('Место', 'Игра');
    final session = sessionOver(['Место']);
    final seen = <String?>[];
    session.addListener(() => seen.add(session.directory));

    await session.scanKnownRoots();

    // Была хотя бы одна папка, о которой сообщили до её осмотра.
    expect(seen.whereType<String>(), isNotEmpty);
    // К концу указатель гаснет: висящий, он врал бы о продолжающейся работе.
    expect(session.directory, isNull);
  });

  // Выбор папки отменяет начатое, а не встаёт за ним в очередь.
  test('выбор папки отменяет уже идущий заход', () async {
    await gameDir('Широкое', 'Ненужная');
    await gameDir('Узкое', 'Нужная');
    final session = sessionOver(['Широкое']);

    final wide = session.scanKnownRoots();
    final narrow = session.scanOnly(p.join(tmp.path, 'Узкое'));
    await Future.wait([wide, narrow]);

    expect(session.found.map((g) => g.title), ['Нужная']);
  });

  // Остановка — это «хватит искать», а не «забудь найденное».
  test('остановка оставляет найденное', () async {
    await gameDir('Место', 'Игра');
    final session = sessionOver(['Место']);
    await session.scanKnownRoots();

    session.stop();

    expect(session.found.map((g) => g.title), ['Игра']);
    expect(session.isRunning, isFalse);
  });

  test('остановка на середине не роняет заход', () async {
    for (var i = 0; i < 8; i++) {
      await gameDir('Место', 'Игра $i');
    }
    final session = sessionOver(['Место']);

    final running = session.scanKnownRoots();
    session.stop();
    await running;

    expect(session.isRunning, isFalse);
    // Прерванный заход законченным не считается — иначе интерфейс сказал бы
    // «ничего не нашлось» там, где просто не досмотрели.
    expect(session.isComplete, isFalse);
  });

  test('уже добавленные папки не предлагаются', () async {
    final known = await gameDir('Место', 'Уже есть');
    await gameDir('Место', 'Ещё нет');
    final session = sessionOver(['Место'], existing: {known.path});

    await session.scanKnownRoots();

    expect(session.found.map((g) => g.title), ['Ещё нет']);
  });

  test('несуществующее место не роняет заход', () async {
    final session = sessionOver(['нет-такого']);

    await session.scanKnownRoots();

    expect(session.found, isEmpty);
    expect(session.isComplete, isTrue);
  });
}
