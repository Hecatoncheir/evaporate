import 'dart:io';

String formatBytes(num bytes, {int decimals = 1}) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = unit == 0 ? 0 : decimals;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

String formatSpeed(num bytesPerSecond) => '${formatBytes(bytesPerSecond)}/с';

String formatDuration(Duration duration) {
  if (duration.inMinutes < 1) return 'меньше минуты';
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '$minutes мин';
  if (minutes == 0) return '$hours ч';
  return '$hours ч $minutes мин';
}

String formatEta(int seconds) {
  if (seconds <= 0) return '—';
  final duration = Duration(seconds: seconds);
  if (duration.inDays > 1) return '> ${duration.inDays} дн';
  final h = duration.inHours;
  final m = duration.inMinutes.remainder(60);
  final s = duration.inSeconds.remainder(60);
  if (h > 0) return '$h ч $m мин';
  if (m > 0) return '$m мин';
  return '$s с';
}

String formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

/// Имя устройства попадает в манифест снапшота, чтобы на другой машине
/// было видно, откуда приехал сейв.
String currentDeviceName() {
  final host = Platform.localHostname;
  if (host.isNotEmpty) return host;
  return Platform.operatingSystem;
}

String currentPlatformKey() {
  if (Platform.isMacOS) return 'macos';
  if (Platform.isWindows) return 'windows';
  if (Platform.isLinux) return 'linux';
  return Platform.operatingSystem;
}

String platformLabel(String key) => switch (key) {
  'macos' => 'macOS',
  'windows' => 'Windows',
  'linux' => 'Linux',
  _ => key,
};
