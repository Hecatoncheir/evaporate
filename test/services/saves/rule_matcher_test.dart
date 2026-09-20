import 'package:evaporate/models/game.dart';
import 'package:evaporate/models/save_profile.dart';
import 'package:evaporate/models/save_snapshot.dart';
import 'package:evaporate/services/saves/rule_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

/// Правило пакета и правило этого устройства — разные записи, и сводит их
/// одно место: по нему и раскладывают файлы, и показывают человеку, куда
/// они лягут.
void main() {
  const matcher = RuleMatcher();

  SavePathRule rule({
    required String id,
    required String label,
    String template = '{HOME}/saves',
  }) => SavePathRule(id: id, label: label, template: template);

  Game gameWith(List<SavePathRule> rules) => Game(
    id: 'g1',
    title: 'Игра',
    addedAt: DateTime(2026),
    saveProfile: SaveProfile(rules: rules),
  );

  test('совпадение по id сильнее совпадения по метке', () {
    final byId = rule(id: 'r1', label: 'Другая метка');
    final byLabel = rule(id: 'r2', label: 'Сохранения');
    final game = gameWith([byLabel, byId]);

    final found = matcher.localFor(game, rule(id: 'r1', label: 'Сохранения'));

    expect(found?.id, 'r1');
  });

  // По метке снимок с Windows ложится в macOS-путь той же игры: id на
  // разных устройствах свои, а метку человек видит и узнаёт.
  test('без совпадения по id идут по метке, не глядя на регистр', () {
    final game = gameWith([rule(id: 'здешний', label: ' Сохранения ')]);

    final found = matcher.localFor(
      game,
      rule(id: 'чужой', label: 'сохранения'),
    );

    expect(found?.id, 'здешний');
  });

  // Двоякость решать молча нельзя: файлы лягут не туда, и узнает об этом
  // человек по пропавшему прогрессу.
  test('две одинаковые метки — отказ, а не первая попавшаяся', () {
    final game = gameWith([
      rule(id: 'a', label: 'Сохранения'),
      rule(id: 'b', label: 'Сохранения'),
    ]);

    expect(
      matcher.localFor(game, rule(id: 'чужой', label: 'Сохранения')),
      isNull,
    );
  });

  // Путь из чужого манифеста здесь не будет записан никогда: он с другой
  // машины, и подставлять его значило бы обещать несуществующее место.
  test('без своего правила целью не становится чужое', () {
    final game = gameWith([rule(id: 'r1', label: 'Настройки')]);

    expect(matcher.localFor(game, rule(id: 'r9', label: 'Сохранения')), isNull);
  });

  test('предпросмотр показывает те же цели, что и раскладка', () {
    final local = rule(id: 'r1', label: 'Сохранения', template: '{HOME}/s');
    final game = gameWith([local]);
    final snapshot = SaveSnapshot(
      id: 's1',
      gameId: game.id,
      gameTitle: game.title,
      createdAt: DateTime(2026),
      deviceName: 'та машина',
      platform: 'windows',
      sizeBytes: 1,
      archivePath: '',
      rules: [rule(id: 'чужой', label: 'Сохранения', template: 'C:/чужое')],
    );

    final targets = matcher.preview(game, snapshot);

    expect(targets.keys, ['Сохранения']);
    expect(targets['Сохранения'], local.resolve(gameDir: null));
  });
}
