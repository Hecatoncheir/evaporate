import '../services/download/download_engine.dart';
import 'app_localizations.dart';

/// Переводимые подписи, нужные не только интерфейсу, но и блокам.
///
/// Блок сообщает о состоянии движка строкой в `Notice`, и брать подпись из
/// `lib/ui/labels.dart` значило бы тянуть в блок слой интерфейса. Остальные
/// подписи живут там; сюда переезжает только то, что нужно ниже него.

/// Состояние движка загрузок словами.
String engineStateLabel(L l, EngineState state) => switch (state) {
  EngineState.stopped => l.engineStopped2,
  EngineState.starting => l.engineStarting,
  EngineState.ready => l.engineReady,
  EngineState.failed => l.statusError,
};
