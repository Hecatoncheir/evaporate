import 'dart:convert';
import 'dart:io';

import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/models/game.dart';

/// Кладёт игру в библиотеку такой, как если бы она такой лежала на диске:
/// дописывает её в `library.json` и перечитывает файл.
///
/// Нужна там, где тесту важно поле, которое снаружи не правят вовсе —
/// оценка, обложка, предел снимков. Событий-снимков «вот вся игра» у
/// библиотеки нет намеренно (они затирали пришедшее, пока шли), и заводить
/// такое ради тестов значило бы вернуть его в код.
Future<Game> seedGame(LibraryBloc library, AppPaths paths, Game game) async {
  await library.persist();
  final file = File(paths.libraryFile);
  final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  json['games'] = [
    for (final entry in json['games'] as List<dynamic>)
      (entry as Map<String, dynamic>)['id'] == game.id ? game.toJson() : entry,
  ];
  await file.writeAsString(jsonEncode(json));

  final before = library.state.gameById(game.id);
  library.add(const LibraryLoadRequested());
  final loaded = await library.stream
      .firstWhere((s) => !identical(s.gameById(game.id), before))
      .timeout(const Duration(seconds: 10));
  return loaded.gameById(game.id)!;
}
