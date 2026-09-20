part of 'proxy_form_bloc.dart';

/// Набранный адрес прокси и то, что из него следует.
class ProxyForm extends Equatable {
  const ProxyForm({
    required this.saved,
    required this.host,
    required this.port,
    required this.user,
    required this.password,
  });

  /// Форма, открытая на сохранённых настройках.
  factory ProxyForm.of(ProxySettings saved) => ProxyForm(
    saved: saved,
    host: saved.host,
    port: '${saved.port}',
    user: saved.username,
    password: saved.password,
  );

  /// Что стоит в настройках сейчас: с ним сверяется набранное.
  final ProxySettings saved;

  final String host;

  /// Порт строкой: в поле бывает и пусто, и «80800» — число из этого
  /// получается не всегда, а показать набранное надо как есть.
  final String port;

  final String user;
  final String password;

  /// Порт, если он и правда порт.
  ///
  /// Ноль и шестьдесят пять тысяч пятьсот тридцать шесть портами не
  /// бывают: первый значит «любой свободный», а второго нет вовсе.
  int? get parsedPort {
    final value = int.tryParse(port.trim());
    if (value == null || value <= 0 || value > 65535) return null;
    return value;
  }

  /// Порт набран, но портом не является.
  bool get portInvalid => port.trim().isNotEmpty && parsedPort == null;

  /// Набранное отличается от сохранённого — есть что применять.
  bool get dirty => draft != saved;

  /// Что уйдёт в настройки по «Применить».
  ///
  /// Негодный порт оставляет прежний: применять такое нельзя, и [canApply]
  /// не даст, — но черновик обязан оставаться собираемым, иначе рядом с
  /// клавишей нечего было бы показать.
  ProxySettings get draft => saved.copyWith(
    host: host.trim(),
    port: parsedPort ?? saved.port,
    username: user.trim(),
    password: password,
  );

  /// Применять можно то, что включено, заполнено, с настоящим портом и
  /// отличается от сохранённого.
  ///
  /// Последнее — ответ человеку вместо сообщения: нажал, клавиша погасла,
  /// значит применено. Прежде здесь всплывал `SnackBar` мимо `Notice`.
  bool get canApply => saved.enabled && !portInvalid && draft.isUsable && dirty;

  ProxyForm copyWith({
    ProxySettings? saved,
    String? host,
    String? port,
    String? user,
    String? password,
  }) => ProxyForm(
    saved: saved ?? this.saved,
    host: host ?? this.host,
    port: port ?? this.port,
    user: user ?? this.user,
    password: password ?? this.password,
  );

  ProxyForm withHost(String value) => copyWith(host: value);
  ProxyForm withPort(String value) => copyWith(port: value);
  ProxyForm withUser(String value) => copyWith(user: value);
  ProxyForm withPassword(String value) => copyWith(password: value);

  @override
  List<Object?> get props => [saved, host, port, user, password];
}
