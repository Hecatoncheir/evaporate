import 'dart:io';

import 'package:evaporate/bloc/restore_preview/restore_preview_bloc.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/models/save_profile.dart';
import 'package:evaporate/models/save_snapshot.dart';
import 'package:evaporate/services/saves/save_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/temp_dir.dart';

/// Строка «когда здешние сохранения менялись» стоит в диалоге, где человек
/// решает, затирать ли свой прогресс. Врать ей нельзя, а молчать — можно.
///
/// Там же считается, куда лягут файлы: считает это менеджер, а не диалог.
void main() {
  late Directory tmp;
  late AppPaths paths;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_freshness_');
    paths = AppPaths.custom(
      dataDir: p.join(tmp.path, 'data'),
      defaultInstallDir: p.join(tmp.path, 'games'),
    );
  });

  tearDown(() async {
    await deleteTempDir(tmp);
  });

  Game gameWith(String template) => Game(
    id: 'g1',
    title: 'Игра',
    addedAt: DateTime.now(),
    saveProfile: SaveProfile(
      rules: [
        SavePathRule(
          id: 'r1',
          label: SavePathRule.defaultLabel,
          template: template,
        ),
      ],
    ),
  );

  /// Снимок той же игры: правило у него то же, иначе раскладывать нечего.
  SaveSnapshot snapshotAt(DateTime createdAt, {String? template}) =>
      SaveSnapshot(
        id: 's1',
        gameId: 'g1',
        gameTitle: 'Игра',
        createdAt: createdAt,
        deviceName: 'здесь',
        platform: 'linux',
        rules: [
          if (template != null)
            SavePathRule(
              id: 'r1',
              label: SavePathRule.defaultLabel,
              template: template,
            ),
        ],
        archivePath: '',
        fileCount: 1,
        sizeBytes: 1,
      );

  /// Блок, которому уже задали вопрос, и ответ, которого дождались.
  Future<RestorePreview> preview(
    SaveManager saves,
    Game game, {
    DateTime? snapshotAt_,
    String? template,
  }) async {
    final bloc = RestorePreviewBloc(saves);
    addTearDown(bloc.close);
    bloc.add(
      RestorePreviewRequested(
        game: game,
        snapshot: snapshotAt(snapshotAt_ ?? DateTime.now(), template: template),
      ),
    );
    return bloc.stream
        .firstWhere((state) => state.known)
        .timeout(const Duration(seconds: 5), onTimeout: () => bloc.state);
  }

  test('до ответа ничего не утверждается', () {
    final bloc = RestorePreviewBloc(SaveManager(paths: paths));
    addTearDown(bloc.close);

    expect(bloc.state.known, isFalse);
    expect(bloc.state.changedAt, isNull);
    expect(bloc.state.targets, isEmpty);
  });

  test('прочитанное время правки доходит до состояния', () async {
    final saves = Directory(p.join(tmp.path, 'сейвы'));
    await saves.create(recursive: true);
    await File(p.join(saves.path, 'slot.sav')).writeAsString('прогресс');

    final state = await preview(
      SaveManager(paths: paths),
      gameWith(saves.path),
      template: saves.path,
    );

    expect(state.known, isTrue);
    expect(state.changedAt, isNotNull);
    expect(state.targets.values, [saves.path]);
  });

  test('отсутствие сохранений — это ответ, а не молчание', () async {
    final state = await preview(
      SaveManager(paths: paths),
      gameWith(p.join(tmp.path, 'нет-такой-папки')),
    );

    expect(state.known, isTrue);
    expect(state.changedAt, isNull);
  });

  // Раньше диалог на неудавшемся чтении показывал «сохранения здесь ещё не
  // менялись» — то есть утверждал то, чего не знал, ровно там, где человек
  // решает, затирать ли свой прогресс.
  test('неудавшееся чтение оставляет «не знаем», а не «их не было»', () async {
    final bloc = RestorePreviewBloc(_UnreadableSaves(paths));
    addTearDown(bloc.close);
    bloc.add(
      RestorePreviewRequested(
        game: gameWith(p.join(tmp.path, 'что угодно')),
        snapshot: snapshotAt(DateTime.now()),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(
      bloc.state.known,
      isFalse,
      reason: 'не прочитали — значит, и сказать нечего',
    );
  });

  // Восстановить снимок, снятый до того, как здесь наигрались, — это откат
  // прогресса, и сказать об этом надо до нажатия, а не после.
  test('свежие здешние сохранения помечаются как новее снимка', () async {
    final saves = Directory(p.join(tmp.path, 'сейвы'));
    await saves.create(recursive: true);
    await File(p.join(saves.path, 'slot.sav')).writeAsString('прогресс');

    final state = await preview(
      SaveManager(paths: paths),
      gameWith(saves.path),
      snapshotAt_: DateTime.now().subtract(const Duration(days: 1)),
    );

    expect(state.newer, isTrue);
  });

  // Часы разных устройств расходятся, а время изменения файла хранится с
  // разной точностью: допуск здесь тот же, что у массового переноса.
  test('минутная разница за откат не считается', () async {
    final saves = Directory(p.join(tmp.path, 'сейвы'));
    await saves.create(recursive: true);
    await File(p.join(saves.path, 'slot.sav')).writeAsString('прогресс');

    final state = await preview(
      SaveManager(paths: paths),
      gameWith(saves.path),
      snapshotAt_: DateTime.now().subtract(const Duration(seconds: 30)),
    );

    expect(state.newer, isFalse);
  });
}

/// Менеджер, которому папку сохранений не отдают: так ведёт себя каталог,
/// закрытый правами.
class _UnreadableSaves extends SaveManager {
  _UnreadableSaves(AppPaths paths) : super(paths: paths);

  @override
  Future<DateTime?> lastLocalChange(Game game) async =>
      throw const FileSystemException('нет прав');
}
