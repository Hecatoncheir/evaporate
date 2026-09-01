import 'dart:io';

import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/core/save_path_template.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/services/saves/ludusavi_catalog.dart';
import 'package:evaporate/services/saves/ludusavi_cli.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

void main() {
  late Directory tmp;
  late AppPaths paths;
  late SettingsBloc settings;
  final opened = <LibraryBloc>[];

  /// Манифест с той же игрой, что знает и Ludusavi: так видно, кто из двух
  /// источников выиграл.
  const manifestYaml = '''
Hollow Knight:
  files:
    <home>/ИзМанифеста:
      tags:
        - save
''';

  const findBody = '{"games": {"Hollow Knight": {"score": 1.0}}}';

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

  LibraryBloc blocWith({required ProcessRun run}) {
    final bloc = LibraryBloc(
      paths: paths,
      settings: settings,
      ludusavi: LudusaviCli(run: run),
      savePaths: LudusaviCatalog(
        cacheFile: p.join(tmp.path, 'paths.json'),
        fetch: (uri) async => manifestYaml,
      ),
    );
    opened.add(bloc);
    return bloc;
  }

  /// Ludusavi установлен и знает игру.
  ProcessRun answering({required String preview}) {
    return (exe, args) async {
      if (args.contains('--version')) {
        return ProcessResult(0, 0, 'ludusavi 0.29.1', '');
      }
      if (args.first == 'find') return ProcessResult(0, 0, findBody, '');
      return ProcessResult(0, 0, preview, '');
    };
  }

  Future<ProcessResult> notInstalled(String exe, List<String> args) async {
    throw ProcessException(exe, args, 'нет файла', 2);
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

  Future<Game> addGame(LibraryBloc bloc, String title) async {
    final id = const Uuid().v4();
    bloc.add(GameAdded(id: id, title: title));
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

  test('пути берутся у Ludusavi, а не из манифеста', () async {
    final dir = p.join(SavePathTemplate.expand('{APPSUPPORT}'), 'HK');
    final preview =
        '{"games": {"Hollow Knight": {"files": {'
        '"${p.join(dir, 'user1.dat').replaceAll(r'\', r'\\')}": '
        '{"ignored": false, "failed": false}}}}}';
    final bloc = blocWith(run: answering(preview: preview));

    final game = await addGame(bloc, 'Hollow Knight');
    final state = await lookup(bloc, game);

    final rules = state.gameById(game.id)!.saveProfile.rules;
    expect(rules, hasLength(1));
    expect(SavePathTemplate.expand(rules.single.template), dir);
    expect(state.notice!.message, contains('из Ludusavi'));
  });

  test('без установленного Ludusavi работает манифест', () async {
    final bloc = blocWith(run: notInstalled);

    final game = await addGame(bloc, 'Hollow Knight');
    final state = await lookup(bloc, game);

    final rules = state.gameById(game.id)!.saveProfile.rules;
    expect(rules, hasLength(1));
    expect(rules.single.template, '{HOME}/ИзМанифеста');
    expect(state.notice!.message, contains('из базы'));
  });

  // Установленный, но сломанный Ludusavi не должен отбирать у нас манифест.
  test('сбой Ludusavi не отменяет запасной источник', () async {
    final bloc = blocWith(
      run: (exe, args) async {
        if (args.contains('--version')) {
          return ProcessResult(0, 0, 'ludusavi 0.29.1', '');
        }
        return ProcessResult(0, 0, 'паника: манифест повреждён', '');
      },
    );

    final game = await addGame(bloc, 'Hollow Knight');
    final state = await lookup(bloc, game);

    expect(state.gameById(game.id)!.saveProfile.rules, hasLength(1));
    expect(state.notice!.message, contains('из базы'));
    expect(state.notice!.isError, isFalse);
  });

  test('игра, которой нет нигде, честно об этом сообщает', () async {
    final bloc = blocWith(run: notInstalled);

    final game = await addGame(bloc, 'Своя Игра Без Базы');
    final state = await lookup(bloc, game);

    expect(state.gameById(game.id)!.saveProfile.rules, isEmpty);
    expect(state.notice!.message, contains('ничего не нашлось'));
  });

  // Реестр мы не переносим: промолчать значило бы обмануть.
  test('о ветках реестра сообщается отдельно', () async {
    final dir = p.join(SavePathTemplate.expand('{APPSUPPORT}'), 'HK');
    final preview =
        '{"games": {"Hollow Knight": {"files": {'
        '"${p.join(dir, 'user1.dat').replaceAll(r'\', r'\\')}": '
        '{"ignored": false, "failed": false}}, '
        '"registry": {"HKEY_CURRENT_USER/Software/HK": {"failed": false}}}}}';
    final bloc = blocWith(run: answering(preview: preview));

    final game = await addGame(bloc, 'Hollow Knight');
    final state = await lookup(bloc, game);

    expect(state.notice!.message, contains('в реестре осталось веток: 1'));
  });

  test('повторный запрос не плодит одинаковые правила', () async {
    final dir = p.join(SavePathTemplate.expand('{APPSUPPORT}'), 'HK');
    final preview =
        '{"games": {"Hollow Knight": {"files": {'
        '"${p.join(dir, 'user1.dat').replaceAll(r'\', r'\\')}": '
        '{"ignored": false, "failed": false}}}}}';
    final bloc = blocWith(run: answering(preview: preview));

    final game = await addGame(bloc, 'Hollow Knight');
    await lookup(bloc, game);
    final again = bloc.state.gameById(game.id)!;
    final state = await lookup(bloc, again);

    expect(state.gameById(game.id)!.saveProfile.rules, hasLength(1));
    expect(state.notice!.message, contains('уже заданы'));
  });
}
