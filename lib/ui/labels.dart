import 'package:gamepads/gamepads.dart';

import '../input/gamepad_binding.dart';
import '../input/gamepad_service.dart';
import '../input/nav_action.dart';
import '../l10n/app_localizations.dart';
import '../core/format.dart';
import '../models/download_task.dart';
import '../models/save_profile.dart';
import '../models/save_snapshot.dart';
import '../services/download/download_engine.dart';

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

String downloadStateLabel(L l, DownloadState state) => switch (state) {
  DownloadState.waiting => l.stateQueued,
  DownloadState.active => l.statusDownloading,
  DownloadState.paused => l.statusPaused,
  DownloadState.complete => l.stateCompleted,
  DownloadState.error => l.statusError,
  DownloadState.removed => l.stateCancelled,
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

/// Состояние движка загрузок словами.
String engineStateLabel(L l, EngineState state) => switch (state) {
  EngineState.stopped => l.engineStopped2,
  EngineState.starting => l.engineStarting,
  EngineState.ready => l.engineReady,
  EngineState.failed => l.statusError,
};

/// Скорость: «1,2 МБ» плюс единица времени, которая тоже переводится.
String speedLabel(L l, num bytesPerSecond) =>
    l.speedPerSecond(formatBytes(bytesPerSecond));

/// Откуда взялся снимок сохранений.
String snapshotOriginLabel(L l, SnapshotOrigin origin) => switch (origin) {
  SnapshotOrigin.manual => l.originManual,
  SnapshotOrigin.autoOnExit => l.originAutoOnExit,
  SnapshotOrigin.autoOnLaunch => l.originAutoOnLaunch,
  SnapshotOrigin.imported => l.originImported,
  SnapshotOrigin.preRestore => l.originPreRestore,
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
