import 'package:path/path.dart' as p;

import '../core/format.dart';
import '../core/save_path_template.dart';

/// Одна папка (или файл) с сохранениями. Хранится шаблоном, а не абсолютным
/// путём — см. [SavePathTemplate].
class SavePathRule {
  /// Метка по умолчанию. Намеренно не переводится: по ней правила
  /// сопоставляются между устройствами, и переведись она — снимок с русской
  /// машины перестал бы сходиться с правилом на английской. Показывают её
  /// переведённой (`ruleLabelText`), а хранят как есть.
  static const defaultLabel = 'Сохранения';

  /// Метки для набора путей одной игры.
  ///
  /// По метке сейвы сопоставляются между устройствами, поэтому имя папки
  /// надёжнее порядкового номера: «Saves» и «Config» на другой машине
  /// встанут на свои места, а «Сохранения 1» и «Сохранения 2» перепутались
  /// бы при любой перестановке путей.
  ///
  /// Единственному пути метка не нужна — у него та, что по умолчанию, и она
  /// одинакова на всех языках. А совпавшие имена (`profiles/alice/save` и
  /// `profiles/bob/save`) разводятся добавлением родительской папки, пока
  /// не станут различаться: одинаковые метки склеили бы разные сейвы.
  static List<String> labelsFor(List<String> templates) {
    if (templates.length == 1) return [defaultLabel];

    final parts = [for (final t in templates) p.split(t)];
    final labels = [for (final _ in templates) <String>[]];
    for (var depth = 1; depth <= 4; depth++) {
      for (var i = 0; i < parts.length; i++) {
        labels[i] = parts[i].sublist(
          parts[i].length - depth < 0 ? 0 : parts[i].length - depth,
        );
      }
      final joined = [for (final l in labels) l.join('/')];
      if (joined.toSet().length == joined.length) return joined;
    }
    // Развести не вышло — дальше выручает только порядковый номер.
    return [
      for (var i = 0; i < templates.length; i++)
        '${p.basename(templates[i])} ${i + 1}',
    ];
  }

  /// Убирает пути, лежащие внутри других: забрав папку, мы заберём и всё,
  /// что в ней, а второе правило только удвоило бы снимок.
  static List<String> withoutNested(List<String> templates) {
    final sorted = [...templates]..sort((a, b) => a.length.compareTo(b.length));
    final kept = <String>[];
    for (final template in sorted) {
      final covered = kept.any(
        (parent) => template == parent || template.startsWith('$parent/'),
      );
      if (!covered) kept.add(template);
    }
    return kept;
  }

  const SavePathRule({
    required this.id,
    required this.label,
    required this.template,
    this.platform,
    this.kind,
  });

  final String id;
  final String label;
  final String template;

  /// `macos` / `windows` / `linux`, либо null — правило для всех платформ.
  /// Позволяет одной игре иметь разные пути сейвов на разных ОС и всё равно
  /// синхронизироваться между ними: сопоставление идёт по [label].
  final String? platform;

  /// Тип исходного пути в момент создания снимка. Старые настройки и
  /// пакеты этого поля не имеют, поэтому `null` означает прежнее поведение
  /// с каталогом. В самих настройках поле обычно не задано; SaveManager
  /// добавляет его в правило, записываемое в манифест.
  final SavePathKind? kind;

  bool get isPortable => SavePathTemplate.isPortable(template);

  bool appliesToCurrentPlatform() =>
      platform == null || platform == currentPlatformKey();

  /// Нужна ли правилу папка игры, чтобы развернуться.
  bool get needsGameDir => SavePathTemplate.needsGameDir(template);

  /// Абсолютный путь на этой машине; `null`, если правило указывает внутрь
  /// папки игры, а та неизвестна — игра не установлена. Пустой строкой или
  /// путём с `{GAME}` внутри возвращать нельзя: такой путь молча не нашёлся
  /// бы, и снимок вышел бы неполным без единого слова об этом.
  String? resolve({String? gameDir}) {
    if (needsGameDir && (gameDir == null || gameDir.isEmpty)) return null;
    return SavePathTemplate.expand(template, gameDir: gameDir);
  }

  SavePathRule copyWith({
    String? label,
    String? template,
    Object? platform = _u,
    Object? kind = _u,
  }) {
    return SavePathRule(
      id: id,
      label: label ?? this.label,
      template: template ?? this.template,
      platform: platform == _u ? this.platform : platform as String?,
      kind: kind == _u ? this.kind : kind as SavePathKind?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'template': template,
    if (platform != null) 'platform': platform,
    if (kind != null) 'kind': kind!.name,
  };

  factory SavePathRule.fromJson(Map<String, dynamic> json) => SavePathRule(
    id: json['id'] as String,
    label: json['label'] as String? ?? defaultLabel,
    template: json['template'] as String,
    platform: json['platform'] as String?,
    kind: SavePathKind.values.cast<SavePathKind?>().firstWhere(
      (kind) => kind?.name == json['kind'],
      orElse: () => null,
    ),
  );

  static const _u = Object();
}

enum SavePathKind { file, directory }

class SaveProfile {
  const SaveProfile({
    this.rules = const [],
    this.autoSnapshotOnExit = true,
    this.keepSnapshots = 20,
  });

  final List<SavePathRule> rules;

  /// Снимать сейв автоматически после выхода из игры.
  final bool autoSnapshotOnExit;

  /// Сколько снапшотов держать на диске; старые ротируются.
  final int keepSnapshots;

  bool get isConfigured => rules.isNotEmpty;

  List<SavePathRule> get rulesForCurrentPlatform =>
      rules.where((r) => r.appliesToCurrentPlatform()).toList();

  SaveProfile copyWith({
    List<SavePathRule>? rules,
    bool? autoSnapshotOnExit,
    int? keepSnapshots,
  }) {
    return SaveProfile(
      rules: rules ?? this.rules,
      autoSnapshotOnExit: autoSnapshotOnExit ?? this.autoSnapshotOnExit,
      keepSnapshots: keepSnapshots ?? this.keepSnapshots,
    );
  }

  Map<String, dynamic> toJson() => {
    'rules': rules.map((r) => r.toJson()).toList(),
    'autoSnapshotOnExit': autoSnapshotOnExit,
    'keepSnapshots': keepSnapshots,
  };

  factory SaveProfile.fromJson(Map<String, dynamic> json) => SaveProfile(
    rules: (json['rules'] as List<dynamic>? ?? [])
        .map((e) => SavePathRule.fromJson(e as Map<String, dynamic>))
        .toList(),
    autoSnapshotOnExit: json['autoSnapshotOnExit'] as bool? ?? true,
    keepSnapshots: json['keepSnapshots'] as int? ?? 20,
  );
}
