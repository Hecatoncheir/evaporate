import 'package:evaporate/ui/widgets/frame_step.dart';
import 'package:flutter_test/flutter_test.dart';

/// Шаг часов украшений — одно правило на все украшения.
void main() {
  test('первый шаг — один кадр', () {
    expect(FrameStep().next(const Duration(seconds: 5)), closeTo(1 / 60, 1e-9));
  });

  test('кадр чаще шестидесяти в секунду пропускается', () {
    final step = FrameStep()..next(Duration.zero);
    expect(step.next(const Duration(milliseconds: 8)), isNull);
    expect(step.next(const Duration(milliseconds: 17)), closeTo(0.017, 1e-9));
  });

  // Подвисший кадр или возвращение свёрнутого окна — один маленький шаг, а
  // не прыжок: частицы атмосферы получали шаг во всю паузу и разлетались.
  test('длинная пауза даёт шаг не длиннее двух кадров', () {
    final step = FrameStep()..next(Duration.zero);
    expect(step.next(const Duration(seconds: 3)), FrameStep.maxStep);
  });

  test('после сброса отсчёт начинается заново', () {
    final step = FrameStep()..next(Duration.zero);
    step.reset();
    expect(step.next(const Duration(minutes: 1)), closeTo(1 / 60, 1e-9));
  });
}
