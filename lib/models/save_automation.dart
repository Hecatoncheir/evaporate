import 'package:equatable/equatable.dart';

/// Что приложение делает с сохранениями само: куда выкладывать снимки
/// для других устройств и когда снимать их без нажатия.
///
/// Одним значением: это читает блок сохранений и больше никто, и правится
/// оно из одной карточки. На диске запись плоская, ключи прежние.
class SaveAutomation extends Equatable {
  const SaveAutomation({
    this.syncFolder,
    this.autoExportToSync = true,
    this.autoSnapshotOnExit = true,
    this.autoSnapshotOnLaunch = false,
  });

  /// Папка облачной синхронизации (Dropbox/Syncthing/iCloud), через которую
  /// сейвы переезжают между устройствами.
  final String? syncFolder;
  final bool autoExportToSync;

  /// Выкладывать ли снятое в папку синхронизации прямо сейчас: и
  /// разрешено, и есть куда.
  bool get exportsToSync => autoExportToSync && syncFolder != null;

  /// Глобальный дефолт: снимать сейв после выхода из игры.
  final bool autoSnapshotOnExit;

  /// Глобальный дефолт: снимать сейв ещё и перед запуском игры.
  final bool autoSnapshotOnLaunch;

  SaveAutomation copyWith({
    Object? syncFolder = _unset,
    bool? autoExportToSync,
    bool? autoSnapshotOnExit,
    bool? autoSnapshotOnLaunch,
  }) => SaveAutomation(
    syncFolder: syncFolder == _unset ? this.syncFolder : syncFolder as String?,
    autoExportToSync: autoExportToSync ?? this.autoExportToSync,
    autoSnapshotOnExit: autoSnapshotOnExit ?? this.autoSnapshotOnExit,
    autoSnapshotOnLaunch: autoSnapshotOnLaunch ?? this.autoSnapshotOnLaunch,
  );

  Map<String, dynamic> toJson() => {
    if (syncFolder != null) 'syncFolder': syncFolder,
    'autoExportToSync': autoExportToSync,
    'autoSnapshotOnExit': autoSnapshotOnExit,
    'autoSnapshotOnLaunch': autoSnapshotOnLaunch,
  };

  factory SaveAutomation.fromJson(Map<String, dynamic> json) => SaveAutomation(
    syncFolder: json['syncFolder'] as String?,
    autoExportToSync: json['autoExportToSync'] as bool? ?? true,
    autoSnapshotOnExit: json['autoSnapshotOnExit'] as bool? ?? true,
    autoSnapshotOnLaunch: json['autoSnapshotOnLaunch'] as bool? ?? false,
  );

  @override
  List<Object?> get props => [
    syncFolder,
    autoExportToSync,
    autoSnapshotOnExit,
    autoSnapshotOnLaunch,
  ];

  static const _unset = Object();
}
