import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/models/game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final added = DateTime(2026);

  group('игра для задачи загрузки', () {
    test('находится по id задачи', () {
      final game = Game(
        id: 'a',
        title: 'A',
        addedAt: added,
        downloadTaskId: 'task',
      );
      final state = LibraryState(games: [game]);

      expect(state.gameForTask('task'), same(game));
    });

    // Id, записанный прежним движком, с нынешним не совпадёт, а infohash
    // раздачи тот же — по нему игру и узнают.
    test('находится по infohash, когда id задачи записан иначе', () {
      final game = Game(
        id: 'a',
        title: 'A',
        addedAt: added,
        downloadTaskId: 'old-gid',
        infoHash: 'abc',
      );
      final state = LibraryState(games: [game]);

      expect(state.gameForTask('abc'), same(game));
    });

    test('чужая задача игры не находит', () {
      final state = LibraryState(
        games: [Game(id: 'a', title: 'A', addedAt: added, infoHash: 'abc')],
      );

      expect(state.gameForTask('other'), isNull);
    });
  });
}
