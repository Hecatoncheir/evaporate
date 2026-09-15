import 'dart:io';

import 'package:evaporate/bloc/save_freshness_cubit.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/models/save_profile.dart';
import 'package:evaporate/services/saves/save_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Строка «когда здешние сохранения менялись» стоит в диалоге, где человек
/// решает, затирать ли свой прогресс. Врать ей нельзя, а молчать — можно.
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
    if (await tmp.exists()) await tmp.delete(recursive: true);
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

  test('до чтения диска ничего не утверждается', () {
    final cubit = SaveFreshnessCubit(SaveManager(paths: paths));
    addTearDown(cubit.close);

    expect(cubit.state.known, isFalse);
    expect(cubit.state.changedAt, isNull);
  });

  test('прочитанное время правки доходит до состояния', () async {
    final saves = Directory(p.join(tmp.path, 'сейвы'));
    await saves.create(recursive: true);
    await File(p.join(saves.path, 'slot.sav')).writeAsString('прогресс');

    final cubit = SaveFreshnessCubit(SaveManager(paths: paths));
    addTearDown(cubit.close);
    await cubit.read(gameWith(saves.path));

    expect(cubit.state.known, isTrue);
    expect(cubit.state.changedAt, isNotNull);
  });

  test('отсутствие сохранений — это ответ, а не молчание', () async {
    final cubit = SaveFreshnessCubit(SaveManager(paths: paths));
    addTearDown(cubit.close);
    await cubit.read(gameWith(p.join(tmp.path, 'нет-такой-папки')));

    expect(cubit.state.known, isTrue);
    expect(cubit.state.changedAt, isNull);
  });

  // Раньше диалог на неудавшемся чтении показывал «сохранения здесь ещё не
  // менялись» — то есть утверждал то, чего не знал, ровно там, где человек
  // решает, затирать ли свой прогресс.
  test('неудавшееся чтение оставляет «не знаем», а не «их не было»', () async {
    final cubit = SaveFreshnessCubit(_UnreadableSaves(paths));
    addTearDown(cubit.close);
    await cubit.read(gameWith(p.join(tmp.path, 'что угодно')));

    expect(
      cubit.state.known,
      isFalse,
      reason: 'не прочитали — значит, и сказать нечего',
    );
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
