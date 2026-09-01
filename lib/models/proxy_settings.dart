import 'package:equatable/equatable.dart';

/// Каким прокси пользуется движок загрузок.
enum ProxyKind {
  http,

  /// SOCKS5 — единственный вариант, при котором через прокси идёт и обмен
  /// с пирами, а не только обращения к трекерам.
  socks5,
}

extension ProxyKindLabel on ProxyKind {
  String get label => switch (this) {
    ProxyKind.http => 'HTTP',
    ProxyKind.socks5 => 'SOCKS5',
  };
}

/// Настройки прокси для движка загрузок.
class ProxySettings extends Equatable {
  const ProxySettings({
    this.enabled = false,
    this.kind = ProxyKind.socks5,
    this.host = '',
    this.port = 8080,
    this.username = '',
    this.password = '',
    this.bypass = const [],
    this.useForSteam = true,
  });

  final bool enabled;
  final ProxyKind kind;
  final String host;
  final int port;
  final String username;
  final String password;

  /// Хосты в обход прокси (`--no-proxy`).
  final List<String> bypass;

  /// Пускать ли через прокси запросы к каталогу Steam. Отдельный флаг:
  /// качать через прокси и ходить в Steam напрямую — обычное желание.
  final bool useForSteam;

  /// Включён и заполнен настолько, чтобы его можно было применить.
  bool get isUsable => enabled && host.trim().isNotEmpty && port > 0;

  bool get hasCredentials => username.trim().isNotEmpty;

  /// Адрес без учётных данных: логин и пароль передаются отдельными
  /// параметрами, чтобы не попадать в строку адреса и в логи.
  String get uri {
    final trimmed = host.trim().replaceFirst(RegExp(r'^\w+://'), '');
    final scheme = kind == ProxyKind.socks5 ? 'socks5' : 'http';
    return '$scheme://$trimmed:$port';
  }

  ProxySettings copyWith({
    bool? enabled,
    ProxyKind? kind,
    String? host,
    int? port,
    String? username,
    String? password,
    List<String>? bypass,
    bool? useForSteam,
  }) {
    return ProxySettings(
      enabled: enabled ?? this.enabled,
      kind: kind ?? this.kind,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      bypass: bypass ?? this.bypass,
      useForSteam: useForSteam ?? this.useForSteam,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'kind': kind.name,
    'host': host,
    'port': port,
    if (username.isNotEmpty) 'username': username,
    if (password.isNotEmpty) 'password': password,
    if (bypass.isNotEmpty) 'bypass': bypass,
    'useForSteam': useForSteam,
  };

  factory ProxySettings.fromJson(Map<String, dynamic> json) => ProxySettings(
    enabled: json['enabled'] as bool? ?? false,
    kind: ProxyKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => ProxyKind.socks5,
    ),
    host: json['host'] as String? ?? '',
    port: json['port'] as int? ?? 8080,
    username: json['username'] as String? ?? '',
    password: json['password'] as String? ?? '',
    bypass: (json['bypass'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList(),
    useForSteam: json['useForSteam'] as bool? ?? true,
  );

  @override
  List<Object?> get props => [
    enabled,
    kind,
    host,
    port,
    username,
    password,
    bypass,
    useForSteam,
  ];
}
