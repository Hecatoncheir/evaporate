import 'package:intl/intl.dart';

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

/// Размер словами языка: «1,5 ГБ», «1.5 GB».
///
/// Здесь, а не в `lib/ui`: размер уходит человеку и из сообщений блока и
/// сервисов — «снимок слишком велик: …». `formatBytes` из ядра остался для
/// журналов и всегда пишет «1.5 GB»: языка там нет.
String bytesLabel(L l, num bytes) {
  final units = [l.unitB, l.unitKB, l.unitMB, l.unitGB, l.unitTB];
  if (bytes <= 0) return '0 ${units.first}';
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final number = NumberFormat.decimalPatternDigits(
    locale: l.localeName,
    decimalDigits: unit == 0 ? 0 : 1,
  );
  return '${number.format(value)} ${units[unit]}';
}

/// Дата и время по правилам языка: «22.09.2026 14:05», «9/22/2026 14:05».
///
/// Прежде всегда «дд.мм.гггг» — и в английском интерфейсе тоже.
String dateTimeLabel(L l, DateTime value) =>
    DateFormat.yMd(l.localeName).add_Hm().format(value.toLocal());

/// Целое с разрядами по правилам языка: «222 495», «222,495».
String countLabel(L l, int value) =>
    NumberFormat.decimalPattern(l.localeName).format(value);
