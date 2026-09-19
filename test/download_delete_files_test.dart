import 'dart:io';

import 'package:evaporate/bloc/downloads/downloads_bloc.dart';
import 'package:evaporate/models/download_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/temp_dir.dart';

/// «Удалить совсем вместе с файлами» стирает без возврата, и ошибиться тут
/// можно ровно один раз — чужой библиотекой игр.
void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('evaporate_delete_');
  });

  tearDown(() async {
    await deleteTempDir(root);
  });

  Future<String> write(String relative) async {
    final file = File(p.join(root.path, relative));
    await file.parent.create(recursive: true);
    await file.writeAsString('данные');
    return file.path;
  }

  test('папку раздачи сносит целиком, а корень не трогает', () async {
    final soul = await write('Другая игра/важное.bin');
    final a = await write('Наша игра/data/a.pak');
    final b = await write('Наша игра/game.exe');

    await DownloadsBloc.deleteDownloaded(
      DownloadTask(
        id: 't1',
        name: 'Наша игра',
        state: DownloadState.active,
        dir: root.path,
        files: [a, b],
      ),
      root: root.path,
    );

    expect(Directory(p.join(root.path, 'Наша игра')).existsSync(), isFalse);
    expect(root.existsSync(), isTrue);
    expect(File(soul).existsSync(), isTrue, reason: 'соседи не при чём');
  });

  // Самое опасное место. У раздачи из одного файла, лежащего прямо в корне,
  // «папка раздачи» — это сам корень загрузок. Снести его значило бы унести
  // всю библиотеку игр заодно с этой.
  test('однофайловая раздача в корне не сносит корень', () async {
    final soul = await write('Другая игра/важное.bin');
    final single = await write('одиночка.iso');

    await DownloadsBloc.deleteDownloaded(
      DownloadTask(
        id: 't2',
        name: 'одиночка.iso',
        state: DownloadState.active,
        dir: root.path,
        files: [single],
      ),
      root: root.path,
    );

    expect(File(single).existsSync(), isFalse, reason: 'свой файл убираем');
    expect(root.existsSync(), isTrue);
    expect(
      File(soul).existsSync(),
      isTrue,
      reason: 'корень загрузок сносить нельзя ни при каких условиях',
    );
  });

  test('файл за пределами корня остаётся нетронутым', () async {
    final outside = File(
      p.join(root.parent.path, 'чужое-${root.path.hashCode}'),
    );
    await outside.writeAsString('не наше');
    addTearDown(() {
      if (outside.existsSync()) outside.deleteSync();
    });

    await DownloadsBloc.deleteDownloaded(
      DownloadTask(
        id: 't3',
        name: 'подлог',
        state: DownloadState.active,
        files: [outside.path],
      ),
      root: root.path,
    );

    expect(outside.existsSync(), isTrue);
  });

  test('пропавшие файлы не считаются ошибкой', () async {
    await DownloadsBloc.deleteDownloaded(
      DownloadTask(
        id: 't4',
        name: 'уже убрано',
        state: DownloadState.active,
        files: [p.join(root.path, 'нет-такого.bin')],
      ),
      root: root.path,
    );

    expect(root.existsSync(), isTrue);
  });
}
