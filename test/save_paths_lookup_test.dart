import 'dart:io';

import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/core/save_path_template.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/models/save_profile.dart';
import 'package:evaporate/services/saves/ludusavi_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

void main() {
  late Directory tmp;
  late AppPaths paths;
  late SettingsBloc settings;
  final opened = <LibraryBloc>[];

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_paths_');
    paths = AppPaths.custom(
      dataDir: p.join(tmp.path, 'data'),
      defaultInstallDir: p.join(tmp.path, 'games'),
    );
    settings = SettingsBloc(paths);
  });

  tearDown(() async {
    // Закрытие блока дописывает библиотеку на диск, поэтому папку
    // сносим только после него.
    for (final bloc in opened) {
      await bloc.close();
    }
    opened.clear();
    await settings.close();
    try {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    } on FileSystemException {
      // Остатки временной папки на результат теста не влияют.
    }
  });

  LibraryBloc blocWith(String manifestYaml) {
    final bloc = LibraryBloc(
      paths: paths,
      settings: settings,
      savePaths: LudusaviCatalog(
        cacheFile: p.join(tmp.path, 'paths.json'),
        fetch: (uri) async => manifestYaml,
      ),
    );
    opened.add(bloc);
    return bloc;
  }

  Future<LibraryState> waitFor(
    LibraryBloc bloc,
    bool Function(LibraryState) condition,
  ) {
    if (condition(bloc.state)) return Future.value(bloc.state);
    return bloc.stream
        .firstWhere(condition)
        .timeout(const Duration(seconds: 10));
  }

  Future<Game> addGame(
    LibraryBloc bloc,
    String title, {
    String? installDir,
  }) async {
    final id = const Uuid().v4();
    bloc.add(GameAdded(id: id, title: title, installDir: installDir));
    final state = await waitFor(bloc, (s) => s.gameById(id) != null);
    return state.gameById(id)!;
  }

  /// Уведомление от прошлого запроса уже лежит в состоянии, поэтому
  /// ждём именно новое — на то у `Notice` и есть счётчик.
  Future<LibraryState> lookup(LibraryBloc bloc, Game game) async {
    final before = bloc.state.notice?.seq ?? 0;
    bloc.add(SavePathsLookupRequested(game));
    return waitFor(
      bloc,
      (s) =>
          (s.notice?.seq ?? 0) > before &&
          !s.isBusy(LibraryBloc.savePathsKey(game.id)),
    );
  }

  test('путь из базы становится правилом', () async {
    final bloc = blocWith('''
Hollow Knight:
  files:
    <home>/ИзМанифеста:
      tags:
        - save
''');

    final game = await addGame(bloc, 'Hollow Knight');
    final state = await lookup(bloc, game);

    final rules = state.gameById(game.id)!.saveProfile.rules;
    expect(rules, hasLength(1));
    expect(rules.single.template, '{HOME}/ИзМанифеста');
    expect(state.notice!.message, contains('из базы'));
  });

  // Ради этого и получилось отказаться от бинарника Ludusavi: `<base>` —
  // самый частый плейсхолдер базы, а папку установки лончер знает сам.
  test('<base> разворачивается в папку игры', () async {
    final installDir = p.join(tmp.path, 'games', 'HK');
    await Directory(p.join(installDir, 'saves')).create(recursive: true);

    final bloc = blocWith('''
Hollow Knight:
  files:
    <base>/saves:
      tags:
        - save
''');

    final game = await addGame(bloc, 'Hollow Knight', installDir: installDir);
    final state = await lookup(bloc, game);

    final rule = state.gameById(game.id)!.saveProfile.rules.single;
    expect(rule.template, '{GAME}/saves');
    expect(rule.resolve(gameDir: installDir), p.join(installDir, 'saves'));
    // Шаблон переносимый: на другом устройстве игра стоит в другом месте,
    // и правило разворачивается туда.
    expect(rule.isPortable, isTrue);
  });

  test('маска раскрывается по тому, что лежит на диске', () async {
    final installDir = p.join(tmp.path, 'games', 'HK');
    await Directory(p.join(installDir, 'profiles', 'alice', 'save'))
        .create(recursive: true);
    await Directory(p.join(installDir, 'profiles', 'bob', 'save'))
        .create(recursive: true);

    final bloc = blocWith('''
Hollow Knight:
  files:
    <base>/profiles/*/save:
      tags:
        - save
''');

    final game = await addGame(bloc, 'Hollow Knight', installDir: installDir);
    final state = await lookup(bloc, game);

    final rules = state.gameById(game.id)!.saveProfile.rules;
    expect(rules, hasLength(2));
    expect(rules.map((r) => r.template).toSet(), {
      '{GAME}/profiles/alice/save',
      '{GAME}/profiles/bob/save',
    });
    // Одинаковые метки склеили бы разные сейвы при переносе.
    expect(rules.map((r) => r.label).toSet(), {'alice/save', 'bob/save'});
  });

  test('маска без совпадений правил не создаёт', () async {
    final installDir = p.join(tmp.path, 'games', 'HK');
    await Directory(installDir).create(recursive: true);

    final bloc = blocWith('''
Hollow Knight:
  files:
    <base>/profiles/*/save:
      tags:
        - save
''');

    final game = await addGame(bloc, 'Hollow Knight', installDir: installDir);
    final state = await lookup(bloc, game);

    expect(state.gameById(game.id)!.saveProfile.rules, isEmpty);
    expect(state.notice!.message, contains('ничего не нашлось'));
  });

  test('игра, которой нет нигде, честно об этом сообщает', () async {
    final bloc = blocWith('Hollow Knight:\n  files:\n');

    final game = await addGame(bloc, 'Своя Игра Без Базы');
    final state = await lookup(bloc, game);

    expect(state.gameById(game.id)!.saveProfile.rules, isEmpty);
    expect(state.notice!.message, contains('ничего не нашлось'));
  });

  // Реестр мы не переносим: промолчать значило бы обмануть.
  test(
    'о ветках реестра сообщается отдельно',
    () async {
      final bloc = blocWith('''
Hollow Knight:
  files:
    <home>/ИзМанифеста:
      tags:
        - save
  registry:
    HKEY_CURRENT_USER/Software/HK:
      tags:
        - save
''');

      final game = await addGame(bloc, 'Hollow Knight');
      final state = await lookup(bloc, game);

      expect(state.notice!.message, contains('в реестре осталось веток: 1'));
    },
    // Ветки реестра попадают в указатель только на Windows: на других
    // системах они не значат ничего.
    skip: !Platform.isWindows,
  );

  test('повторный запрос не плодит одинаковые правила', () async {
    final bloc = blocWith('''
Hollow Knight:
  files:
    <home>/ИзМанифеста:
      tags:
        - save
''');

    final game = await addGame(bloc, 'Hollow Knight');
    await lookup(bloc, game);
    final again = bloc.state.gameById(game.id)!;
    final state = await lookup(bloc, again);

    expect(state.gameById(game.id)!.saveProfile.rules, hasLength(1));
    expect(state.notice!.message, contains('уже заданы'));
  });

  test('шаблон без папки игры не разворачивается в мусор', () {
    final rule = SavePathRule(
      id: 'r1',
      label: SavePathRule.defaultLabel,
      template: '{GAME}/saves',
    );

    expect(rule.resolve(), isNull);
    expect(rule.resolve(gameDir: '/opt/hk'), p.join('/opt/hk', 'saves'));
    expect(SavePathTemplate.needsGameDir(rule.template), isTrue);
  });
}
