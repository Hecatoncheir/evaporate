part of 'settings_bloc.dart';

sealed class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

/// Прочитать настройки с диска при старте приложения.
final class SettingsLoadRequested extends SettingsEvent {
  const SettingsLoadRequested();
}

/// Заменить настройки целиком и записать их на диск.
final class SettingsChanged extends SettingsEvent {
  const SettingsChanged(this.settings);

  final AppSettings settings;

  @override
  List<Object?> get props => [settings];
}
