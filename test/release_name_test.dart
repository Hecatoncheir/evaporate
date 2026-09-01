import 'package:evaporate/services/metadata/release_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('очистка имени раздачи', () {
    test('точки между словами — это пробелы', () {
      expect(ReleaseName.clean('Hollow.Knight'), 'Hollow Knight');
    });

    test('версия отбрасывается', () {
      expect(ReleaseName.clean('Hollow.Knight.v1.5.78.11'), 'Hollow Knight');
    });

    test('релиз-группа после дефиса отбрасывается', () {
      expect(
        ReleaseName.clean('The.Witcher.3.Wild.Hunt-ElAmigos'),
        'The Witcher 3 Wild Hunt',
      );
    });

    test('издание и языковые метки отбрасываются', () {
      expect(
        ReleaseName.clean('The.Witcher.3.Wild.Hunt.GOTY.MULTi15-ElAmigos'),
        'The Witcher 3 Wild Hunt',
      );
    });

    test('содержимое скобок отбрасывается целиком', () {
      expect(ReleaseName.clean('Elden Ring (2022) [RUS/ENG]'), 'Elden Ring');
    });

    // Год в названии игры — часть названия, а не мусор.
    test('число в названии сохраняется', () {
      expect(
        ReleaseName.clean('Cyberpunk 2077 [FitGirl Repack]'),
        'Cyberpunk 2077',
      );
    });

    test('подчёркивания тоже разделители', () {
      expect(ReleaseName.clean('Stardew_Valley_v1.6.9'), 'Stardew Valley');
    });

    test('после слова repack идёт описание сборки, а не название', () {
      expect(ReleaseName.clean('Portal 2 Repack by Xatab MULTi9'), 'Portal 2');
    });

    test('расширение образа убирается', () {
      expect(ReleaseName.clean('Doom.Eternal.iso'), 'Doom Eternal');
    });

    test('номер сборки убирается', () {
      expect(ReleaseName.clean('Factorio Build 12345'), 'Factorio');
    });

    test('пустая строка остаётся пустой', () {
      expect(ReleaseName.clean('   '), '');
    });

    test('имя без мусора не портится', () {
      expect(ReleaseName.clean('Hades II'), 'Hades II');
    });

    test('кириллица сохраняется', () {
      expect(ReleaseName.clean('Мор.Утопия.v1.2.3'), 'Мор Утопия');
    });
  });

  group('похожесть названий', () {
    test('совпадение слово в слово — единица', () {
      expect(ReleaseName.similarity('Hollow Knight', 'hollow knight'), 1);
    });

    test('регистр и пунктуация не влияют', () {
      expect(ReleaseName.similarity('Hades II', 'HADES II!'), 1);
    });

    test('дополнение к игре похоже, но не совпадает', () {
      final score = ReleaseName.similarity(
        'Hollow Knight',
        'Hollow Knight - Official Soundtrack',
      );
      expect(score, greaterThan(0));
      expect(score, lessThan(1));
    });

    test('чужая игра не похожа', () {
      expect(ReleaseName.similarity('Hollow Knight', 'Cyberpunk 2077'), 0);
    });

    test('пустые строки не считаются похожими', () {
      expect(ReleaseName.similarity('', 'Hollow Knight'), 0);
    });
  });
}
