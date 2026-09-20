import '../../models/game.dart';
import '../../models/save_profile.dart';
import '../../models/save_snapshot.dart';

/// Какому правилу этого устройства отвечает правило из пакета.
///
/// Отдельно от менеджера снимков, потому что от этого сопоставления
/// зависят два ответа сразу: куда лягут файлы при восстановлении и что
/// покажет диалог **до** нажатия. Они обязаны совпадать — иначе диалог не
/// предупреждение, а выдумка, — и общий код здесь дешевле любого договора.
class RuleMatcher {
  const RuleMatcher();

  /// Куда лягут файлы снимка на этом устройстве: метка правила → путь.
  ///
  /// Тем же сопоставлением, что и сама раскладка: диалог показывает это до
  /// нажатия, и разойтись им нельзя. Прежде диалог считал это сам, и две
  /// реализации разошлись в двух местах — при двух правилах с одной меткой
  /// он брал первое, а не найдя местного правила, подставлял правило из
  /// снимка, то есть путь с чужой машины, который здесь не будет записан
  /// никогда.
  Map<String, String> preview(Game game, SaveSnapshot snapshot) {
    final targets = <String, String>{};
    for (final rule in snapshot.rules) {
      final local = localFor(game, rule);
      if (local == null) continue;
      final resolved = local.resolve(gameDir: game.installDir);
      if (resolved != null) targets[local.label] = resolved;
    }
    return targets;
  }

  /// Путь из внешнего манифеста никогда не становится локальной целью.
  /// Сопоставляем только с явно настроенными у игры путями: id -> метка.
  SavePathRule? localFor(Game game, SavePathRule incoming) {
    final local = game.saveProfile.rulesForCurrentPlatform;
    for (final rule in local) {
      if (rule.id == incoming.id) return rule;
    }
    final wanted = incoming.label.trim().toLowerCase();
    final matches = local
        .where((rule) => rule.label.trim().toLowerCase() == wanted)
        .toList();
    return matches.length == 1 ? matches.single : null;
  }
}
