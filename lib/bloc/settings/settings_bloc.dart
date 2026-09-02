import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/app_paths.dart';
import '../../core/json_store.dart';
import '../../models/app_settings.dart';
import '../../services/system/autostart.dart';

part 'settings_event.dart';

/// Настройки приложения. Состояние — сам [AppSettings]: отдельная обёртка
/// ничего бы не добавила, объект и так иммутабельный.
class SettingsBloc extends Bloc<SettingsEvent, AppSettings> {
  SettingsBloc(AppPaths paths, {Autostart? autostart})
    : _paths = paths,
      _autostart = autostart ?? Autostart(),
      _store = JsonStore(paths.settingsFile),
      super(AppSettings(installDir: paths.defaultInstallDir)) {
    on<SettingsLoadRequested>(_onLoadRequested);
    on<SettingsChanged>(_onChanged);
  }

  final AppPaths _paths;
  final Autostart _autostart;
  final JsonStore _store;

  Future<void> _onLoadRequested(
    SettingsLoadRequested event,
    Emitter<AppSettings> emit,
  ) async {
    final json = await _store.read();
    var settings = json == null
        ? state
        : AppSettings.fromJson(json, _paths.defaultInstallDir);

    // Про автозапуск спрашиваем саму систему: его могли отключить её
    // средствами, и записанная настройка не должна это переспорить.
    final actual = await _autostart.isEnabled();
    if (actual != settings.launchAtStartup) {
      settings = settings.copyWith(launchAtStartup: actual);
    }
    emit(settings);
  }

  Future<void> _onChanged(
    SettingsChanged event,
    Emitter<AppSettings> emit,
  ) async {
    if (event.settings == state) return;

    var next = event.settings;
    if (next.launchAtStartup != state.launchAtStartup) {
      try {
        await _autostart.setEnabled(next.launchAtStartup);
      } on Object {
        // Не вышло — переключатель не должен показывать несбывшееся.
        next = next.copyWith(launchAtStartup: state.launchAtStartup);
      }
    }

    // Пишем до emit: слушатели состояния (перезапуск демона, повторное
    // чтение файла) не должны обгонять запись на диск.
    await _store.write(next.toJson());
    emit(next);
  }
}
