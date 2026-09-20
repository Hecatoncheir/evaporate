part of 'log_bloc.dart';

sealed class LogEvent extends Equatable {
  const LogEvent();

  @override
  List<Object?> get props => [];
}

/// Показать журнал. Сам по себе он не читается: файл бывает в полмегабайта,
/// а заглядывают в него редко.
final class LogShowRequested extends LogEvent {
  const LogShowRequested();
}

/// Очистить журнал.
final class LogClearRequested extends LogEvent {
  const LogClearRequested();
}
