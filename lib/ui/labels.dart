import 'package:gamepads/gamepads.dart';

import '../input/gamepad_binding.dart';
import '../input/gamepad_service.dart';
import '../input/nav_action.dart';
import '../l10n/app_localizations.dart';
import '../l10n/labels.dart';
import '../models/app_section.dart';
import '../models/download_task.dart';
import '../models/game.dart';
import '../models/save_profile.dart';
import '../models/save_snapshot.dart';

export '../l10n/labels.dart'
    show bytesLabel, countLabel, dateTimeLabel, engineStateLabel;

/// Переводимые подписи для того, что живёт в моделях и во вводе.
///
/// Модели и слой ввода про язык интерфейса ничего не знают и знать не должны:
/// у них нет `BuildContext`, а тащить туда локализацию значило бы смешать
/// данные с их показом. Поэтому подписи собраны здесь, в слое интерфейса, а
/// собственные `label` в моделях остаются для журналов и отладки.
String navActionLabel(L l, NavAction action) => switch (action) {
  NavAction.up => l.navUp,
  NavAction.down => l.navDown,
  NavAction.left => l.navLeft,
  NavAction.right => l.navRight,
  NavAction.confirm => l.hintSelect,
  NavAction.back => l.hintBack,
  NavAction.primaryAction => l.navPrimary,
  NavAction.search => l.hintSearch,
  NavAction.nextSection => l.navNextSection,
  NavAction.prevSection => l.navPreviousSection,
  NavAction.scrollUp => l.navScrollUp,
  NavAction.scrollDown => l.navScrollDown,
};

/// Имя раздела приложения.
///
/// Здесь, а не в самом перечислении: у него нет `BuildContext`, а имя
/// нужно и обойме, и диктору.
String sectionLabel(L l, AppSection section) => switch (section) {
  AppSection.library => l.library,
  AppSection.downloads => l.downloads,
  AppSection.saves => l.saves,
  AppSection.settings => l.settings,
};

/// Состояние игры словами.
///
/// Здесь, а не в модели: у `GameStatus` нет `BuildContext`, а строка нужна и
/// значку состояния, и подписи для экранного диктора — расходиться им нельзя.
String gameStatusLabel(L l, GameStatus status) => switch (status) {
  GameStatus.notInstalled => l.statusNotInstalled,
  GameStatus.downloading => l.statusDownloading,
  GameStatus.paused => l.statusPaused,
  GameStatus.installed => l.statusInstalled,
  GameStatus.running => l.statusRunning,
  GameStatus.error => l.statusError,
};

/// Доля скачанного словами — для экранного диктора: полосу прогресса он
/// не видит, а число ему сказать можно.
String percentLabel(L l, double progress) =>
    l.percentDone((progress.clamp(0.0, 1.0) * 100).round());

String downloadStateLabel(L l, DownloadState state) => switch (state) {
  DownloadState.waiting => l.stateQueued,
  DownloadState.active => l.statusDownloading,
  DownloadState.paused => l.statusPaused,
  DownloadState.complete => l.stateCompleted,
  DownloadState.error => l.statusError,
};

/// Длительность словами: «2 ч 15 мин».
///
/// Единицы отличаются не только словом, но и порядком, поэтому собирать
/// строку из кусков в `format.dart` нельзя — там нет языка.
String formatDurationLabel(L l, Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0 && minutes > 0) return l.durationHoursMinutes(hours, minutes);
  if (hours > 0) return l.durationHours(hours);
  if (minutes > 0) return l.durationMinutes(minutes);
  return l.durationLessThanMinute;
}

/// Оставшееся время загрузки.
String formatEtaLabel(L l, int? seconds) {
  if (seconds == null || seconds <= 0) return '';
  final duration = Duration(seconds: seconds);
  // Больше суток — точность здесь уже никому не нужна.
  if (duration.inDays > 0) return l.etaMoreThanDays(duration.inDays);
  return formatDurationLabel(l, duration);
}

/// Состояние геймпада словами.
String gamepadStatusLabel(L l, GamepadStatus status) {
  final message = status.message;
  if (message != null) return message;
  if (!status.available) return l.gamepadNotInitialised;
  if (status.devices.isEmpty) return l.gamepadNone;
  return status.soleDevice ?? l.gamepadDevices(status.devices.length);
}

/// Скорость: «1,2 МБ» плюс единица времени, которая тоже переводится.
String speedLabel(L l, num bytesPerSecond) =>
    l.speedPerSecond(bytesLabel(l, bytesPerSecond));

/// Откуда взялся снимок сохранений.
String snapshotOriginLabel(L l, SnapshotOrigin origin) => switch (origin) {
  SnapshotOrigin.manual => l.originManual,
  SnapshotOrigin.autoOnExit => l.originAutoOnExit,
  SnapshotOrigin.autoOnLaunch => l.originAutoOnLaunch,
  SnapshotOrigin.imported => l.originImported,
  SnapshotOrigin.preRestore => l.originPreRestore,
};

/// Откуда берётся игра — словами языка интерфейса. `GameSource.logLabel`
/// — для журнала и русский; в интерфейс он и попадал: в английской локали
/// строка источника читалась «Source: Локальная папка: …».
String gameSourceLabel(L l, GameSourceKind kind) => switch (kind) {
  GameSourceKind.magnet => l.sourceMagnet,
  GameSourceKind.torrentFile => l.sourceTorrent,
  GameSourceKind.localFolder => l.sourceFolder,
};

/// Подпись метки правила.
///
/// Хранится метка неизменной — по ней правила сопоставляются между
/// устройствами. Переводится только показ, и только для значения по
/// умолчанию: всё, что человек вписал сам, остаётся как вписано.
String ruleLabelText(L l, String label) =>
    label == SavePathRule.defaultLabel ? l.saves : label;

/// Подпись кнопки геймпада.
///
/// Почти все называются буквами и в переводе не нуждаются — переводится
/// единственная словесная.
String gamepadButtonLabel(L l, GamepadButton button) =>
    button == GamepadButton.touchpad ? l.buttonTouchpad : button.label;

/// Короткая подпись хода загрузки поверх обложки.
///
/// Процента может не быть вовсе: у задачи в очереди он ещё не начинался, у
/// метаданных не из чего считаться, а без размера раздачи — не от чего. Во
/// всех этих случаях подпись говорит, что происходит, а не «0%».
String downloadProgressShort(L l, DownloadTask task) => switch (task) {
  _ when task.isQueued => l.inQueue,
  _ when task.isMetadata => l.metadataShort,
  _ when task.state == DownloadState.paused => l.pausedShort,
  _ when task.totalBytes == 0 => '…',
  _ => '${(task.progress * 100).toStringAsFixed(0)}%',
};
