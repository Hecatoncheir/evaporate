import 'dart:async';
import 'dart:io';

import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/models/save_profile.dart';
import 'package:evaporate/services/saves/restore_transaction.dart';
import 'package:evaporate/services/system/app_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/temp_dir.dart';

/// Возврат застрявших сейвов и сама раскладка встречаются на одних и тех же
/// путях, и встреча эта не выдуманная: автоснимок занятость не проверяет,
/// а возврат зовётся перед каждым снимком.
void main() {
  late Directory tmp;
  late String target;
  late RestoreTransaction restore;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_restore_');
    target = p.join(tmp.path, 'saves');
    restore = RestoreTransaction(
      localizations: LRu.new,
      maxSnapshotBytes: 1 << 30,
      rename: (entity, destination) => entity.rename(destination),
      log: () => AppLog(
        path: p.join(tmp.path, 'evaporate.log'),
        previousPath: p.join(tmp.path, 'evaporate.log.1'),
      ),
    );
  });
  tearDown(() => deleteTempDir(tmp));

  Game game() => Game(
    id: 'g',
    title: 'Игра',
    addedAt: DateTime(2026),
    saveProfile: SaveProfile(
      rules: [SavePathRule(id: 'r', label: 'Сохранения', template: target)],
    ),
  );

  List<String> leftovers() => [
    for (final entity in tmp.listSync())
      if (p.basename(entity.path).contains('.evaporate-'))
        p.basename(entity.path),
  ];

  // Возврат удалял любую заготовку `evaporate-new` — и ту, что прямо сейчас
  // наполняла раскладка: `guard` хранилища — счётчик, а не замок.
  test('возврат посреди раскладки не трогает её заготовку', () async {
    await Directory(target).create();
    await File(p.join(target, 'old.sav')).writeAsString('прежнее');
    final gate = Completer<void>();
    final plan = restore.buildPlan(
      [
        _Source('data/r/first.sav', 'первый'),
        _Source('data/r/second.sav', 'второй', gate: gate.future),
      ],
      {'r': RestoreTarget(path: target, isFile: false)},
    );

    final committing = restore.commit(plan, wipeTarget: true);
    // Первый файл уже лёг в заготовку, второй ждёт.
    while (!tmp.listSync().any((e) => e.path.contains('evaporate-new'))) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await restore.recoverInterrupted(game());
    gate.complete();
    await committing;

    expect(
      Directory(target).listSync().map((e) => p.basename(e.path)).toSet(),
      {'first.sav', 'second.sav'},
    );
  });

  // Переименование дату файла не меняет, и «последняя отодвинутая» по
  // `modified` оказывалась той, что дольше всех не трогали.
  test('на место встаёт копия, отодвинутая последней', () async {
    final older = RestoreTransaction.backupPathFor(target, DateTime(2026, 1));
    final newer = RestoreTransaction.backupPathFor(target, DateTime(2026, 9));
    // Дата папок — наоборот: январскую копию создаём позже, и выбор по
    // `modified` взял бы её.
    await Directory(newer).create();
    await File(p.join(newer, 'slot.sav')).writeAsString('сентябрь');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await Directory(older).create();
    await File(p.join(older, 'slot.sav')).writeAsString('январь');

    final left = await restore.recoverInterrupted(game());

    expect(File(p.join(target, 'slot.sav')).readAsStringSync(), 'сентябрь');
    expect(left, [older], reason: 'оставшуюся копию называют');
  });

  test('копия рядом с целой целью остаётся и называется', () async {
    await Directory(target).create();
    final copy = RestoreTransaction.backupPathFor(target, DateTime(2026));
    await Directory(copy).create();

    final left = await restore.recoverInterrupted(game());

    expect(left, [copy]);
    expect(Directory(copy).existsSync(), isTrue);
    expect(leftovers(), [p.basename(copy)]);
  });
}

/// Источник с заданным содержимым; [gate] задерживает запись.
class _Source implements RestoreSource {
  _Source(this.name, this.text, {this.gate});

  @override
  final String name;
  final String text;
  final Future<void>? gate;

  @override
  int get size => text.length;

  @override
  Future<void> writeTo(String path) async {
    await gate;
    await File(path).parent.create(recursive: true);
    await File(path).writeAsString(text);
  }
}
