/// Скорость в КБ/с так, как её пишет прототип: до тысячи — килобайты,
/// дальше — мегабайты с [digits] знаками после точки. Ноль — байты:
/// «0 КБ/с» читалось бы как «немного», а приёма нет совсем.
String formatRate(int kilobytesPerSecond, {int digits = 2}) =>
    kilobytesPerSecond == 0
    ? '0 Б/с'
    : kilobytesPerSecond < 1000
    ? '$kilobytesPerSecond КБ/с'
    : '${(kilobytesPerSecond / 1000).toStringAsFixed(digits)} МБ/с';

/// Доля 0…1 целыми процентами.
int percent(double fraction) => (fraction * 100).round();

/// Сыгранное время: «24 ч 10 мин», «6 ч», «40 мин».
String formatPlayed(Duration played) {
  final hours = played.inHours, minutes = played.inMinutes % 60;
  if (hours == 0) return '$minutes мин';
  return minutes == 0 ? '$hours ч' : '$hours ч $minutes мин';
}

/// Трафик: до тысячи — гигабайты, дальше — терабайты с одной цифрой.
String formatTraffic(int gb) => gb < 1000
    ? '$gb ГБ'
    : '${(gb / 1000).toStringAsFixed(1).replaceAll('.', ',')} ТБ';

/// Число с неразрывным пробелом в разрядах: «1 284», как
/// `toLocaleString('ru-RU')` в прототипе.
String formatThousands(int n) {
  final digits = '$n';
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write('\u00A0');
    out.write(digits[i]);
  }
  return out.toString();
}

/// Сколько осталось качать [gb] гигабайт на скорости [kbPerSecond]:
/// «осталось 7 ч 54 мин», «осталось 12 мин». Время — следствие скорости,
/// а не число рядом с ней.
String formatEta(double gb, int kbPerSecond) {
  if (kbPerSecond <= 0) return 'время не определено';
  final minutes = (gb * 1e6 / kbPerSecond / 60).round();
  final h = minutes ~/ 60, m = minutes % 60;
  return h == 0 ? 'осталось $m мин' : 'осталось $h ч $m мин';
}
