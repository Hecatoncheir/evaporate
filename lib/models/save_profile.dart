import '../core/format.dart';
import '../core/save_path_template.dart';

/// Одна папка (или файл) с сохранениями. Хранится шаблоном, а не абсолютным
/// путём — см. [SavePathTemplate].
class SavePathRule {
  const SavePathRule({
    required this.id,
    required this.label,
    required this.template,
    this.platform,
  });

  final String id;
  final String label;
  final String template;

  /// `macos` / `windows` / `linux`, либо null — правило для всех платформ.
  /// Позволяет одной игре иметь разные пути сейвов на разных ОС и всё равно
  /// синхронизироваться между ними: сопоставление идёт по [label].
  final String? platform;

  bool get isPortable => SavePathTemplate.isPortable(template);

  bool appliesToCurrentPlatform() =>
      platform == null || platform == currentPlatformKey();

  String resolve() => SavePathTemplate.expand(template);

  SavePathRule copyWith({
    String? label,
    String? template,
    Object? platform = _u,
  }) {
    return SavePathRule(
      id: id,
      label: label ?? this.label,
      template: template ?? this.template,
      platform: platform == _u ? this.platform : platform as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'template': template,
    if (platform != null) 'platform': platform,
  };

  factory SavePathRule.fromJson(Map<String, dynamic> json) => SavePathRule(
    id: json['id'] as String,
    label: json['label'] as String? ?? 'Сохранения',
    template: json['template'] as String,
    platform: json['platform'] as String?,
  );

  static const _u = Object();
}

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
