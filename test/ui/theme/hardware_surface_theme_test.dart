import 'package:evaporate/ui/theme.dart';
import 'package:flutter_test/flutter_test.dart';

/// Материал корпуса смешивается при смене схемы по полям. Поле, забытое в
/// `lerp`, молча застревает в прежней схеме: переключишь на день — а тень
/// у панели останется ночной, и никто этого не заметит в коде.
void main() {
  const night = HardwareSurfaceTheme.arclight;
  const day = HardwareSurfaceTheme.cartridge;

  test('на концах смены схемы получается ровно своя схема', () {
    expect(night.lerp(day, 0).values, night.values);
    expect(night.lerp(day, 1).values, day.values);
    expect(day.lerp(night, 1).values, night.values);
  });

  test('copyWith без аргументов ничего не теряет', () {
    expect(night.copyWith().values, night.values);
    expect(day.copyWith().values, day.values);
  });

  test('схемы различаются в каждом поле, которое их различает', () {
    // Иначе поле незачем держать в теме — ему место в константе.
    final same = [
      for (var i = 0; i < night.values.length; i++)
        if (night.values[i] == day.values[i]) i,
    ];
    expect(same, isEmpty);
  });

  // То же правило для палитры: двадцать полей, выписанных руками в `lerp`
  // и `copyWith`, — ровно то место, где новое поле забывают.
  test('палитра смешивается по всем полям', () {
    const dark = EvaporatePalette.dark;
    const light = EvaporatePalette.light;

    expect(dark.lerp(light, 0).values, dark.values);
    expect(dark.lerp(light, 1).values, light.values);
    expect(dark.copyWith().values, dark.values);
  });
}
