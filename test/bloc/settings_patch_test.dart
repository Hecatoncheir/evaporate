import 'dart:io';

import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/temp_dir.dart';

/// Правка настроек после ожидания — системного диалога выбора папки.
///
/// Настройки захватывались до `await getDirectoryPath()`, и правка, которую
/// человек успевал сделать, пока диалог открыт, затиралась снимком.
void main() {
  late Directory tmp;
  late SettingsBloc settings;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_patch_');
    settings = SettingsBloc(
      AppPaths.custom(
        dataDir: p.join(tmp.path, 'data'),
        defaultInstallDir: p.join(tmp.path, 'games'),
      ),
    );
  });

  tearDown(() async {
    await settings.close();
    await deleteTempDir(tmp);
  });

  test('правка ложится на текущие настройки, а не на прежние', () async {
    // Пока «открыт диалог», человек меняет другое.
    settings
      ..add(SettingsPatched((current) => current.copyWith(maxConcurrent: 5)))
      ..add(
        SettingsPatched(
          (s) => s.withSaves((s) => s.copyWith(syncFolder: '/sync')),
        ),
      );

    final state = await settings.stream
        .firstWhere((s) => s.saves.syncFolder == '/sync')
        .timeout(const Duration(seconds: 5));

    expect(state.maxConcurrent, 5, reason: 'правка не затёрла соседнюю');
  });

  test('правка без изменений на диск не пишет', () async {
    settings.add(SettingsPatched((s) => s));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(
      File(p.join(tmp.path, 'data', 'settings.json')).existsSync(),
      isFalse,
    );
  });
}
