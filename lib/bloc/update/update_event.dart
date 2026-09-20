part of 'update_bloc.dart';

sealed class UpdateEvent extends Equatable {
  const UpdateEvent();

  @override
  List<Object?> get props => [];
}

/// Спросить у GitHub, есть ли версия новее нашей.
final class UpdateCheckRequested extends UpdateEvent {
  const UpdateCheckRequested();
}

/// Поставить найденное обновление.
final class UpdateInstallRequested extends UpdateEvent {
  const UpdateInstallRequested();
}

/// Загрузчик рассказал, где он сейчас.
final class UpdateProgressed extends UpdateEvent {
  const UpdateProgressed(this.progress);

  final UpdateProgress progress;

  @override
  List<Object?> get props => [progress.phase, progress.fraction];
}

/// Открыть ссылку в браузере.
final class UpdateLinkRequested extends UpdateEvent {
  const UpdateLinkRequested(this.url);

  final String url;

  @override
  List<Object?> get props => [url];
}

/// Спросить систему, стоит ли запись в меню приложений.
final class MenuEntryRefreshed extends UpdateEvent {
  const MenuEntryRefreshed();
}

/// Завести запись в меню приложений или убрать её.
final class MenuEntryToggled extends UpdateEvent {
  const MenuEntryToggled();
}
