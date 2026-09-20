part of 'update_bloc.dart';

/// Что известно об обновлении и об установке.
class UpdateState extends Equatable {
  const UpdateState({
    this.checking = false,
    this.installing = false,
    this.found,
    this.message,
    this.isError = false,
    this.inMenu,
  });

  /// Идёт проверка.
  final bool checking;

  /// Идёт подготовка обновления: скачивание, проверка, распаковка.
  final bool installing;

  /// Версия новее нашей. `null` — не искали или мы и так свежие.
  final Release? found;

  /// Что сказать человеку: итог проверки, ход замены или отказ.
  final String? message;

  final bool isError;

  /// Стоит ли запись в меню приложений. `null` — система её не знает
  /// (везде, кроме Linux) или мы ещё не спрашивали.
  final bool? inMenu;

  UpdateState copyWith({
    bool? checking,
    bool? installing,
    Object? found = _unset,
    Object? message = _unset,
    bool? isError,
    bool? inMenu,
  }) => UpdateState(
    checking: checking ?? this.checking,
    installing: installing ?? this.installing,
    found: found == _unset ? this.found : found as Release?,
    message: message == _unset ? this.message : message as String?,
    isError: isError ?? this.isError,
    inMenu: inMenu ?? this.inMenu,
  );

  @override
  List<Object?> get props => [
    checking,
    installing,
    found?.version,
    message,
    isError,
    inMenu,
  ];

  static const _unset = Object();
}
