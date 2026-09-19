/// Шаг часов украшений между кадрами.
///
/// Один на всех, кто гонит украшения своим тикером: до этого одно и то же
/// правило было выписано трижды, и в одном месте ограничение шага сверху
/// потерялось — частицы после подвисшего кадра получали шаг во всю паузу и
/// разлетались рывком.
class FrameStep {
  /// Чаще шестидесяти раз в секунду не шагаем: на экранах 120 Гц украшение
  /// иначе считалось бы вдвое чаще, а видно этого не было бы.
  static const minInterval = Duration(microseconds: 16000);

  /// Шаг не длиннее двух кадров: возвращение свёрнутого окна или подвисание
  /// приходит одним маленьким шагом, а не прыжком на минуту вперёд.
  static const maxStep = 1 / 30;

  Duration? _previous;

  /// Забыть прошлый кадр — на остановке и запуске часов, иначе первый шаг
  /// после паузы вышел бы длиной во всю паузу.
  void reset() => _previous = null;

  /// Шаг в секундах до кадра [elapsed], или `null`, если кадр пришёл
  /// слишком рано и его надо пропустить.
  double? next(Duration elapsed) {
    final previous = _previous;
    if (previous != null && elapsed - previous < minInterval) return null;
    _previous = elapsed;
    if (previous == null) return 1 / 60;
    final seconds =
        (elapsed - previous).inMicroseconds / Duration.microsecondsPerSecond;
    return seconds.clamp(0.0, maxStep);
  }
}
