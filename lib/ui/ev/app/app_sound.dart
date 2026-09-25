import '../../../services/system/app_shutdown.dart';
import '../sound/ev_sound.dart';

/// Звук окна для приложения и шаг завершения, который его глушит.
///
/// Включён, если его не выключили в настройках ([enabled]): выключенный
/// движок и не заводится.
///
/// Глушить обязательно: на Windows процесс кончается `exit(0)` мимо
/// разбора движка Flutter (`WindowCloseHandler.quit`), и живой поток
/// звукового движка оставлял после каждого закрытия процесс, который не
/// убивался и держал сотни мегабайт до перезагрузки.
(EvSound, ShutdownStep) appSound(EvAudioOut out, {required bool enabled}) {
  final sound = EvSound(out: out, enabled: enabled);
  return (sound, () async => out.dispose());
}
