import 'dart:io';

import 'package:evaporate/bloc/log/log_bloc.dart';
import 'package:evaporate/services/system/app_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/temp_dir.dart';

/// Журнал — единственный способ узнать, что случилось у человека. Читают
/// его по нажатию: файл бывает в полмегабайта, а заглядывают туда редко.
void main() {
  late Directory tmp;
  late AppLog log;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_log_bloc_');
    log = AppLog(
      path: p.join(tmp.path, 'evaporate.log'),
      previousPath: p.join(tmp.path, 'evaporate.1.log'),
    );
  });

  tearDown(() async {
    try {
      await deleteTempDir(tmp);
    } on FileSystemException {
      // Остатки временной папки на результат теста не влияют.
    }
  });

  LogBloc bloc() {
    final logBloc = LogBloc(log: log);
    addTearDown(logBloc.close);
    return logBloc;
  }

  // «Не показывали» и «показали, а там пусто» — разные вещи, и карточка их
  // различает: у первого нет ни рамки, ни слова «пусто».
  test('до нажатия строк нет вовсе', () {
    expect(bloc().state.lines, isNull);
  });

  test('показанное берётся с диска, не дожидаясь записи в очередь', () async {
    final logBloc = bloc();
    // Именно так это и выглядит у человека: записали и тут же смотрим.
    log.write('снимок не снялся: нет прав');

    logBloc.add(const LogShowRequested());
    final state = await logBloc.stream.firstWhere((s) => s.lines != null);

    expect(state.lines!.join(), contains('снимок не снялся'));
    expect(state.busy, isFalse);
  });

  test('очистка оставляет пустой список, а не «не показывали»', () async {
    final logBloc = bloc();
    log.write('что-то случилось');

    logBloc.add(const LogShowRequested());
    await logBloc.stream.firstWhere((s) => s.lines?.isNotEmpty ?? false);
    logBloc.add(const LogClearRequested());
    final state = await logBloc.stream.firstWhere(
      (s) => s.lines?.isEmpty ?? false,
    );

    expect(state.lines, isEmpty);
    expect(await File(log.path).exists(), isFalse);
  });
}
