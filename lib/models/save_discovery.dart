import 'package:equatable/equatable.dart';

/// Что нашлось о сохранениях игры в открытой базе путей.
///
/// Не правила сохранений — те живут в `SaveProfile` и правятся человеком, —
/// а то, что предложила база: её шаблоны и то, что из них уже взято.
/// Одним значением, потому что пишет их один поиск и читает одно
/// сравнение «что из найденного ещё не добавлено».
class SaveDiscovery extends Equatable {
  const SaveDiscovery({
    this.savePathsLookupAttempted = false,
    this.ludusaviTemplates = const [],
    this.ludusaviResolvedPaths = const [],
  });

  /// Попытка, а не только успех — как у поиска в Steam.
  final bool savePathsLookupAttempted;

  /// Исходные шаблоны базы, в том числе ещё не существующие профили с `*`.
  /// Раскрывать их локально можно многократно без обращения к каталогу.
  final List<String> ludusaviTemplates;

  /// Уже добавленные пути: удалённое вручную правило не создаём заново.
  final List<String> ludusaviResolvedPaths;

  SaveDiscovery copyWith({
    bool? savePathsLookupAttempted,
    List<String>? ludusaviTemplates,
    List<String>? ludusaviResolvedPaths,
  }) => SaveDiscovery(
    savePathsLookupAttempted:
        savePathsLookupAttempted ?? this.savePathsLookupAttempted,
    ludusaviTemplates: ludusaviTemplates ?? this.ludusaviTemplates,
    ludusaviResolvedPaths: ludusaviResolvedPaths ?? this.ludusaviResolvedPaths,
  );

  /// Ключи прежние и лежат в общей записи игры: `library.json` разбор
  /// модели на части не трогает.
  Map<String, dynamic> toJson() => {
    'savePathsLookupAttempted': savePathsLookupAttempted,
    'ludusaviTemplates': ludusaviTemplates,
    'ludusaviResolvedPaths': ludusaviResolvedPaths,
  };

  factory SaveDiscovery.fromJson(Map<String, dynamic> json) => SaveDiscovery(
    savePathsLookupAttempted:
        json['savePathsLookupAttempted'] as bool? ?? false,
    // `List.from`, а не `.cast`: `.cast` ленив, и не-строка ронялась бы не
    // здесь, в `try` загрузки, а при первом чтении поля.
    ludusaviTemplates: List<String>.from(
      json['ludusaviTemplates'] as List<dynamic>? ?? const [],
    ),
    ludusaviResolvedPaths: List<String>.from(
      json['ludusaviResolvedPaths'] as List<dynamic>? ?? const [],
    ),
  );

  @override
  List<Object?> get props => [
    savePathsLookupAttempted,
    ludusaviTemplates,
    ludusaviResolvedPaths,
  ];
}
