part of 'proxy_form_bloc.dart';

sealed class ProxyFormEvent extends Equatable {
  const ProxyFormEvent();

  @override
  List<Object?> get props => [];
}

/// Набрали адрес.
final class ProxyHostChanged extends ProxyFormEvent {
  const ProxyHostChanged(this.host);

  final String host;

  @override
  List<Object?> get props => [host];
}

/// Набрали порт — как есть, строкой: в поле бывает и «80800», и пусто.
final class ProxyPortChanged extends ProxyFormEvent {
  const ProxyPortChanged(this.port);

  final String port;

  @override
  List<Object?> get props => [port];
}

/// Набрали имя пользователя.
final class ProxyUserChanged extends ProxyFormEvent {
  const ProxyUserChanged(this.user);

  final String user;

  @override
  List<Object?> get props => [user];
}

/// Набрали пароль.
final class ProxyPasswordChanged extends ProxyFormEvent {
  const ProxyPasswordChanged(this.password);

  final String password;

  @override
  List<Object?> get props => [password];
}

/// Настройки сменились снаружи — например, применили набранное.
final class ProxySavedChanged extends ProxyFormEvent {
  const ProxySavedChanged(this.saved);

  final ProxySettings saved;

  @override
  List<Object?> get props => [saved];
}
