import 'package:evaporate/services/download/download_engine.dart';
import 'package:evaporate/ui/downloads/engine_state_color.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Плашка на странице загрузок и строка состояния берут цвет отсюда оба:
  // сломанный движок обязан гореть цветом ошибки, а не просто «другим».
  test('состояние движка красится смысловым цветом схемы', () {
    for (final palette in [EvaporatePalette.dark, EvaporatePalette.light]) {
      expect(palette.engine(EngineState.ready), palette.accent);
      expect(palette.engine(EngineState.starting), palette.warning);
      expect(palette.engine(EngineState.failed), palette.danger);
      expect(palette.engine(EngineState.stopped), palette.textSecondary);
    }
  });
}
