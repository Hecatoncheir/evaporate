import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/app_paths.dart';
import '../../core/json_store.dart';
import '../../models/app_settings.dart';

part 'settings_event.dart';

/// Настройки приложения. Состояние — сам [AppSettings]: отдельная обёртка
/// ничего бы не добавила, объект и так иммутабельный.
class SettingsBloc extends Bloc<SettingsEvent, AppSettings> {
  SettingsBloc(AppPaths paths)
    : _paths = paths,
      _store = JsonStore(paths.settingsFile),
      super(AppSettings(installDir: paths.defaultInstallDir)) {
    on<SettingsLoadRequested>(_onLoadRequested);
    on<SettingsChanged>(_onChanged);
  }

  final AppPaths _paths;
  final JsonStore _store;

  Future<void> _onLoadRequested(
    SettingsLoadRequested event,
    Emitter<AppSettings> emit,
  ) async {
    final json = await _store.read();
    if (json == null) return;
    emit(AppSettings.fromJson(json, _paths.defaultInstallDir));
  }

  Future<void> _onChanged(
    SettingsChanged event,
    Emitter<AppSettings> emit,
  ) async {
    if (event.settings == state) return;
    // Пишем до emit: слушатели состояния (перезапуск демона, повторное
    // чтение файла) не должны обгонять запись на диск.
    await _store.write(event.settings.toJson());
    emit(event.settings);
  }
}
