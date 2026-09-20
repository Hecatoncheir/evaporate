import 'dart:io';

import 'package:evaporate/bloc/add_game/add_game_bloc.dart';
import 'package:evaporate/bloc/downloads/downloads_bloc.dart';
import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/services/system/autostart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/temp_dir.dart';

/// Окно «Добавить игру» отвечает за то, что попадёт в библиотеку: негодный
/// ввод оно обязано отвергнуть словами, а годный — завести ровно один раз.
void main() {
  late Directory tmp;
  late AppPaths paths;
  late SettingsBloc settings;
  late LibraryBloc library;
  late DownloadsBloc downloads;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_add_game_');
    paths = AppPaths.custom(
      dataDir: p.join(tmp.path, 'data'),
      defaultInstallDir: p.join(tmp.path, 'games'),
    );
    // Настоящий `Autostart` на Windows лезет в реестр человека.
    settings = SettingsBloc(
      paths,
      autostart: Autostart(
        operatingSystem: 'linux',
        homeDir: tmp.path,
        environment: const {},
      ),
    );
    library = LibraryBloc(
      automaticMetadata: false,
      paths: paths,
      settings: settings,
    );
    downloads = DownloadsBloc(
      paths: paths,
      library: library,
      settings: settings,
    );
  });

  tearDown(() async {
    await downloads.close();
    await library.persist();
    await library.close();
    await settings.close();
    try {
      await deleteTempDir(tmp);
    } on FileSystemException {
      // Остатки временной папки на результат теста не влияют.
    }
  });

  AddGameBloc bloc() {
    final add = AddGameBloc(library: library, downloads: downloads);
    addTearDown(add.close);
    return add;
  }

  /// Ждёт, пока игра появится в библиотеке.
  ///
  /// Сперва смотрим состояние: событие могло отработать до подписки, и
  /// тогда ждать нового было бы нечего.
  Future<void> waitForGame() async {
    if (library.state.games.isNotEmpty) return;
    await library.stream
        .firstWhere((state) => state.games.isNotEmpty)
        .timeout(const Duration(seconds: 10));
  }

  /// Ждёт ответа окна: заведённую игру или отказ.
  Future<AddGameForm> submit(AddGameBloc add) {
    add.add(const AddGameSubmitted());
    return add.stream
        .firstWhere((form) => form.addedId != null || form.error != null)
        .timeout(const Duration(seconds: 10));
  }

  group('magnet-ссылка', () {
    test('не magnet — отказ словами, а не молчание', () async {
      final add = bloc();
      add.add(const AddGameMagnetChanged('http://пример/раздача'));

      final form = await submit(add);

      expect(form.addedId, isNull);
      expect(form.error, isNotNull);
      expect(library.state.games, isEmpty);
    });

    test('имя из ссылки становится названием, если своего нет', () async {
      final add = bloc();
      add.add(
        const AddGameMagnetChanged('magnet:?xt=urn:btih:abc&dn=Hollow+Knight'),
      );

      final form = await submit(add);
      await waitForGame();

      expect(form.error, isNull);
      expect(library.state.games.single.title, 'Hollow Knight');
    });

    test('своё название не перебивается именем из ссылки', () async {
      final add = bloc();
      add
        ..add(
          const AddGameMagnetChanged(
            'magnet:?xt=urn:btih:abc&dn=Hollow+Knight',
          ),
        )
        ..add(const AddGameTitleChanged('Моя игра'));

      await submit(add);
      await waitForGame();

      expect(library.state.games.single.title, 'Моя игра');
    });
  });

  group('файл раздачи', () {
    test('без выбранного файла добавлять нечего', () async {
      final add = bloc()
        ..add(const AddGameKindChanged(GameSourceKind.torrentFile));

      final form = await submit(add);

      expect(form.error, isNotNull);
      expect(library.state.games, isEmpty);
    });
  });

  group('папка на диске', () {
    test('пропавшая папка — отказ, а не игра с битым путём', () async {
      final add = bloc()
        ..add(const AddGameKindChanged(GameSourceKind.localFolder))
        ..add(AddGameFolderPicked(p.join(tmp.path, 'унесли-на-другой-диск')));

      final form = await submit(add);

      expect(form.error, isNotNull);
      expect(library.state.games, isEmpty);
    });

    test('папка заводится установленной игрой', () async {
      final dir = await Directory(p.join(tmp.path, 'Тихая гавань')).create();
      final add = bloc()
        ..add(const AddGameKindChanged(GameSourceKind.localFolder))
        ..add(AddGameFolderPicked(dir.path));

      final form = await submit(add);
      await waitForGame();

      expect(form.addedId, isNotNull);
      final game = library.state.games.single;
      expect(game.title, 'Тихая гавань');
      expect(game.status, GameStatus.installed);
      expect(game.installDir, dir.path);
    });
  });

  // Второе нажатие, пока идёт обход папки, завело бы вторую такую же игру.
  test('второе нажатие не в счёт', () async {
    final dir = await Directory(p.join(tmp.path, 'Двойная')).create();
    final add = bloc()
      ..add(const AddGameKindChanged(GameSourceKind.localFolder))
      ..add(AddGameFolderPicked(dir.path))
      ..add(const AddGameSubmitted())
      ..add(const AddGameSubmitted());

    await add.stream.firstWhere((form) => form.addedId != null);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(library.state.games, hasLength(1));
  });

  group('имя из magnet-ссылки', () {
    test('берётся из dn и разворачивает плюсы в пробелы', () {
      expect(
        magnetDisplayName('magnet:?xt=urn:btih:abc&dn=Hollow+Knight'),
        'Hollow Knight',
      );
    });

    test('без dn имени нет', () {
      expect(magnetDisplayName('magnet:?xt=urn:btih:abc'), isNull);
    });

    // Ссылку человек вставляет откуда угодно, и битая доля процентов в ней
    // не повод падать.
    test('негодная последовательность не роняет разбор', () {
      expect(magnetDisplayName('magnet:?dn=%%%'), isNull);
    });
  });
}
