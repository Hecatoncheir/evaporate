import 'dart:io';

import 'package:evaporate/bloc/scan/scan_bloc.dart';
import 'package:evaporate/services/launch/library_scanner.dart';
import 'package:evaporate/services/launch/scan_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/temp_dir.dart';

/// Отбор найденного принадлежит человеку, а находки приходят из обхода
/// сами: разъехаться этим двоим нельзя.
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_scan_bloc_');
  });

  tearDown(() async {
    try {
      await deleteTempDir(tmp);
    } on FileSystemException {
      // Остатки временной папки на результат теста не влияют.
    }
  });

  ScanBloc bloc() {
    final scan = ScanBloc(
      ScanSession(
        existingDirs: const {},
        // Без подделок заход читает настоящий Steam и реестр этой машины:
        // под нагрузкой полного прогона одно это не укладывалось в десять
        // секунд ожидания, а трогать чужое тесту незачем вовсе.
        steamRoots: const [],
        fixedRoots: const [],
        registryQuery: (executable, arguments) async =>
            ProcessResult(0, 0, '', ''),
      ),
    );
    addTearDown(scan.close);
    return scan;
  }

  ScannedGame game(String title, {bool confident = true}) => ScannedGame(
    title: title,
    installDir: p.join(tmp.path, title),
    executablePath: p.join(tmp.path, title, 'game'),
    confident: confident,
  );

  /// Даёт блоку доработать: событие доходит не мгновенно.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  test('уверенная находка отмечена сразу, неуверенная — нет', () {
    final scan = bloc();

    expect(scan.state.isSelected(game('Точно игра')), isTrue);
    expect(
      scan.state.isSelected(game('Может быть', confident: false)),
      isFalse,
    );
  });

  test('снятая галочка запоминается снятой', () async {
    final scan = bloc();
    final extra = game('Лишняя');

    scan.add(ScanGameToggled(extra, selected: false));
    await settle();

    expect(scan.state.isSelected(extra), isFalse);
    expect(scan.state.unchecked, {extra.installDir});
  });

  // Реестр Windows знает всё установленное: отмечать оттуда заранее
  // нельзя — браузер добавился бы в библиотеку игрой.
  test('неуверенную находку отмечают вручную', () async {
    final scan = bloc();
    final maybe = game('Может быть', confident: false);

    scan.add(ScanGameToggled(maybe, selected: true));
    await settle();

    expect(scan.state.isSelected(maybe), isTrue);
    expect(scan.state.checked, {maybe.installDir});
  });

  test('брошенное не папкой отвечает отказом, а не тишиной', () async {
    final scan = bloc();
    final file = File(p.join(tmp.path, 'не папка.txt'));
    await file.writeAsString('ничего важного');

    scan.add(ScanFolderDropped([file.path]));
    await settle();

    expect(scan.state.wrongDrop, isTrue);
  });

  test('брошенная папка сужает поиск и снимает прежний отказ', () async {
    // Игра внутри брошенной папки: по ней и видно, что искали именно там.
    final root = p.join(tmp.path, 'диск');
    final inside = await Directory(p.join(root, 'Найденная'))
        .create(recursive: true);
    final exe = Platform.isWindows ? 'game.exe' : 'game.sh';
    await File(p.join(inside.path, exe)).writeAsString('#!/bin/sh');

    final scan = bloc();
    scan.add(ScanFolderDropped([p.join(tmp.path, 'нет такого')]));
    await settle();
    expect(scan.state.wrongDrop, isTrue);

    scan.add(ScanFolderDropped([root]));
    // Обход настоящий: ждём находку, а не гадаем по времени.
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (scan.state.found.isEmpty && DateTime.now().isBefore(deadline)) {
      await settle();
    }

    expect(scan.state.wrongDrop, isFalse);
    expect(scan.state.found.single.title, 'Найденная');
  });
}
