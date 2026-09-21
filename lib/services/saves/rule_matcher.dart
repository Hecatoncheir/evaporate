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
    for (final local in assign(game, snapshot.rules).values) {
      final resolved = local.resolve(gameDir: game.installDir);
      if (resolved != null) targets[local.label] = resolved;
    }
    return targets;
  }

  /// Какое здешнее правило достаётся каждому правилу пакета: id правила
  /// пакета → здешнее правило. Не нашедших пары здесь нет.
  ///
  /// Два правила пакета, пришедшие к одному здешнему, пары не получают оба:
  /// сопоставленные по одной метке, они молча сливались в одну цель, и
  /// файлы второго ложились поверх первого. Какое из них «то», не знает
  /// никто, — пусть человек увидит оба в списке несопоставленных.
  Map<String, SavePathRule> assign(Game game, List<SavePathRule> incoming) {
    final claims = <String, List<String>>{};
    final locals = <String, SavePathRule>{};
    for (final rule in incoming) {
      final local = localFor(game, rule);
      if (local == null) continue;
      locals[rule.id] = local;
      (claims[local.id] ??= []).add(rule.id);
    }
    return {
      for (final entry in locals.entries)
        if (claims[entry.value.id]!.length == 1) entry.key: entry.value,
    };
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
