import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/app_paths.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';
import '../../services/system/desktop_entry.dart';
import '../../services/system/update_check.dart';
import '../../services/system/update_download.dart';
import '../../services/system/update_installer.dart';

part 'update_event.dart';
part 'update_state.dart';

/// Обновление приложения и то, как оно вообще установлено.
///
/// Блок, а не состояние карточки: и проверка, и замена ходят в сеть и на
/// диск, у обеих есть ход, а у правила «свой `_busy` в экранах не нужен»
/// исключений нет. Проверять это в карточке было нечем — теперь есть.
///
/// Запись в меню приложений живёт здесь же: вопрос у них один — как эта
/// копия поставлена, — и карточка у них одна.
class UpdateBloc extends Bloc<UpdateEvent, UpdateState> {
  UpdateBloc({
    UpdateCheck? check,
    DesktopEntry? desktop,
    this.installer,
    this.download,
    Future<bool> Function(Uri uri)? openLink,
    Future<void> Function()? onRestart,
    L Function()? localizations,
  }) : _check = check ?? UpdateCheck(),
       _desktop = desktop ?? DesktopEntry(),
       _openLink =
           openLink ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication)),
       _onRestart = onRestart ?? windowManager.close,
       _localizations = localizations ?? _defaultLocalizations,
       super(const UpdateState()) {
    on<UpdateCheckRequested>(_onCheck);
    on<UpdateInstallRequested>(_onInstall);
    on<UpdateProgressed>(_onProgressed);
    on<UpdateLinkRequested>(_onLink);
    on<MenuEntryRefreshed>(_onMenuRefreshed);
    on<MenuEntryToggled>(_onMenuToggled);
    add(const MenuEntryRefreshed());
  }

  final UpdateCheck _check;
  final DesktopEntry _desktop;

  /// Подменяются в прогоне. Настоящие заводятся на месте, а не в
  /// конструкторе: обоим нужна папка данных, а `AppPaths` в тестах не
  /// поднимают — карточка же открывается и там.
  final UpdateInstaller? installer;
  final UpdateDownload? download;

  UpdateInstaller get _installer =>
      installer ?? UpdateInstaller(workDir: AppPaths.instance.dataDir);

  UpdateDownload get _download =>
      download ?? UpdateDownload(workDir: AppPaths.instance.dataDir);
  final Future<bool> Function(Uri uri) _openLink;
  final Future<void> Function() _onRestart;
  final L Function() _localizations;

  static L _defaultLocalizations() => LRu();

  L get _l => _localizations();

  /// Есть ли куда записывать запись в меню приложений.
  bool get menuEntrySupported => _desktop.isSupported;

  Future<void> _onCheck(
    UpdateCheckRequested event,
    Emitter<UpdateState> emit,
  ) async {
    if (state.checking) return;
    emit(state.copyWith(checking: true, message: null, found: null));
    try {
      final release = await _check.latest();
      emit(
        state.copyWith(
          checking: false,
          found: release,
          isError: false,
          message: release == null
              ? _l.upToDate
              : _l.newVersionOut(release.version),
        ),
      );
    } on Object catch (error) {
      emit(state.copyWith(checking: false, isError: true, message: '$error'));
    }
  }

  /// Скачивает обновление, проверяет его и запускает замену.
  ///
  /// На Windows дальше работает сам Inno Setup, на macOS и Linux —
  /// POSIX-помощник. Нам остаётся закрыться через тот же путь, что и
  /// обычное закрытие окна, чтобы всё успело лечь на диск.
  Future<void> _onInstall(
    UpdateInstallRequested event,
    Emitter<UpdateState> emit,
  ) async {
    final release = state.found;
    if (release == null || state.installing) return;
    emit(
      state.copyWith(
        installing: true,
        isError: false,
        message: _l.updateRestartNote,
      ),
    );

    try {
      if (!await _installer.canInstall) {
        throw UpdateException(_l.updateNotWritable);
      }
      final staged = await _download.prepare(
        release,
        // Ход приходит из загрузчика — такой же внешний источник, как
        // движок загрузок: он подаёт события наравне с нажатиями.
        onProgress: (progress) => add(UpdateProgressed(progress)),
      );
      await _installer.apply(staged);
      await _onRestart();
    } on Object catch (error) {
      emit(
        state.copyWith(
          installing: false,
          isError: true,
          message: error is UpdateException ? error.message : '$error',
        ),
      );
    }
  }

  void _onProgressed(UpdateProgressed event, Emitter<UpdateState> emit) {
    final progress = event.progress;
    emit(
      state.copyWith(
        message: switch (progress.phase) {
          UpdatePhase.downloading => _l.updateDownloading(
            ((progress.fraction ?? 0) * 100).round(),
          ),
          UpdatePhase.verifying => _l.updateVerifying,
          UpdatePhase.unpacking => _l.updateUnpacking,
          _ => _l.updateRestartNote,
        },
      ),
    );
  }

  /// Ссылку показывали текстом, который надо было выделить и скопировать.
  /// Открыть её — единственное, что с ней делают.
  Future<void> _onLink(
    UpdateLinkRequested event,
    Emitter<UpdateState> emit,
  ) async {
    final target = Uri.tryParse(event.url);
    final opened = target != null && await _openLink(target);
    if (opened) return;
    emit(state.copyWith(isError: true, message: _l.openLinkFailed(event.url)));
  }

  Future<void> _onMenuRefreshed(
    MenuEntryRefreshed event,
    Emitter<UpdateState> emit,
  ) async {
    if (!_desktop.isSupported) return;
    emit(state.copyWith(inMenu: await _desktop.isInstalled()));
  }

  Future<void> _onMenuToggled(
    MenuEntryToggled event,
    Emitter<UpdateState> emit,
  ) async {
    try {
      if (state.inMenu ?? false) {
        await _desktop.remove();
      } else {
        await _desktop.install();
      }
    } on Object catch (error) {
      emit(state.copyWith(isError: true, message: '$error'));
    }
    // Спрашиваем систему заново, а не верим своему намерению: запись могли
    // убрать и мимо нас.
    add(const MenuEntryRefreshed());
  }
}
