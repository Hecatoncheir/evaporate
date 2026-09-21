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

/// Запись настроек. Одна очередь на все: иначе две правки, пришедшие
/// разом, спорили бы, чья запись последняя.
sealed class SettingsWrite extends SettingsEvent {
  const SettingsWrite();
}

/// Поправить настройки функцией от их **текущего** значения и записать.
///
/// Другого способа записать настройки нет, и это нарочно. Прежде был ещё
/// `SettingsChanged` — «вот все настройки целиком», — и шестнадцать мест
/// слали снимок, собранный до ожидания: включил автозапуск и тут же сменил
/// режим окна — второй снимок нёс старый `launchAtStartup`, и обработчик
/// честно выключал автозапуск в системе обратно. Тот же корень, что у
/// прежнего `GameUpdated(game)` в библиотеке.
final class SettingsPatched extends SettingsWrite {
  const SettingsPatched(this.patch);

  final AppSettings Function(AppSettings current) patch;

  @override
  List<Object?> get props => [patch];
}
