import 'package:equatable/equatable.dart';

import 'window_start_mode.dart';

/// Что происходит при запуске: стартовать ли с системой, каким открыть
/// окно и спрашивать ли о новой версии.
///
/// Одним значением: всё это читается ровно один раз, на старте, и правится
/// из одной карточки. На диске запись плоская, ключи прежние.
class StartupSettings extends Equatable {
  const StartupSettings({
    this.launchAtStartup = false,
    this.windowStart = WindowStartMode.remembered,
    this.checkUpdates = true,
  });

  /// Запускать приложение вместе с системой.
  ///
  /// Значение зеркалит состояние самой системы: её и спрашиваем при
  /// загрузке настроек, потому что автозапуск могли отключить снаружи.
  final bool launchAtStartup;

  /// Каким открывать окно при запуске.
  final WindowStartMode windowStart;

  /// Спрашивать при запуске, не вышла ли версия новее.
  ///
  /// Сама проверка ничего не скачивает: установку запускает пользователь.
  final bool checkUpdates;

  StartupSettings copyWith({
    bool? launchAtStartup,
    WindowStartMode? windowStart,
    bool? checkUpdates,
  }) => StartupSettings(
    launchAtStartup: launchAtStartup ?? this.launchAtStartup,
    windowStart: windowStart ?? this.windowStart,
    checkUpdates: checkUpdates ?? this.checkUpdates,
  );

  Map<String, dynamic> toJson() => {
    'launchAtStartup': launchAtStartup,
    'windowStart': windowStart.name,
    'checkUpdates': checkUpdates,
  };

  factory StartupSettings.fromJson(Map<String, dynamic> json) =>
      StartupSettings(
        launchAtStartup: json['launchAtStartup'] as bool? ?? false,
        windowStart: _windowStartFromJson(json),
        checkUpdates: json['checkUpdates'] as bool? ?? true,
      );

  @override
  List<Object?> get props => [launchAtStartup, windowStart, checkUpdates];

  /// Читает режим запуска, понимая и прежние две галочки: файл настроек
  /// у пользователя уже есть, и терять его выбор при обновлении нельзя.
  static WindowStartMode _windowStartFromJson(Map<String, dynamic> json) {
    final name = json['windowStart'] as String?;
    if (name != null) return WindowStartMode.fromName(name);
    if (json['startMaximized'] == true) return WindowStartMode.maximized;
    if (json['rememberWindowSize'] == false) {
      return WindowStartMode.maximized;
    }
    return WindowStartMode.remembered;
  }
}
