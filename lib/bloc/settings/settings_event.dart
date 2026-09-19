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

/// Запись настроек: целиком или правкой. Обе идут одной очередью — иначе
/// правка и замена, пришедшие разом, спорили бы, чья запись последняя.
sealed class SettingsWrite extends SettingsEvent {
  const SettingsWrite();
}

/// Заменить настройки целиком и записать их на диск.
///
/// Годится, когда новое значение собрано прямо сейчас, без ожиданий. Если
/// между чтением настроек и отправкой было ожидание — системный диалог,
/// сеть, — нужен [SettingsPatched]: снимок затёр бы всё, что изменили за
/// это время.
final class SettingsChanged extends SettingsWrite {
  const SettingsChanged(this.settings);

  final AppSettings settings;

  @override
  List<Object?> get props => [settings];
}

/// Поправить настройки функцией от их **текущего** значения и записать.
final class SettingsPatched extends SettingsWrite {
  const SettingsPatched(this.patch);

  final AppSettings Function(AppSettings current) patch;

  @override
  List<Object?> get props => [patch];
}
