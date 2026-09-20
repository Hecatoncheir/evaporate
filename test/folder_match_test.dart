import 'package:evaporate/services/saves/folder_match.dart';
import 'package:flutter_test/flutter_test.dart';

/// Мерка «похоже ли имя папки на название игры». По ней и ищут папки
/// сохранений, и отбирают изменившееся за сеанс игры, — поэтому она одна.
void main() {
  int scoreOf(String folder, String title) =>
      FolderMatch.score(FolderMatch.normalize(folder), title);

  String needle(String title) => FolderMatch.normalize(title);

  test('знаки и регистр в сравнении не участвуют', () {
    expect(
      FolderMatch.normalize('  The Witcher 3: Wild Hunt '),
      'the witcher 3 wild hunt',
    );
  });

  test('точное совпадение — полные очки', () {
    expect(scoreOf('Hollow Knight', needle('hollow knight')), 100);
  });

  test('папка внутри названия и наоборот — вхождение', () {
    expect(scoreOf('Hollow', needle('hollow knight')), 70);
    expect(scoreOf('Hollow Knight Silksong', needle('hollow knight')), 70);
  });

  // Иначе папка `Sea` совпала бы с «Sea of Thieves», а заодно и с половиной
  // остальных: сохранения ушли бы не той игре.
  test('совпадение по двум-трём буквам не в счёт', () {
    expect(scoreOf('Sea', needle('sea of thieves')), 0);
  });

  // Слова ищут в строке, а не в её словах, и это нарочно: папку игра
  // чаще называет слитно — `DeadCells`, `HollowKnight`.
  test('все слова нашлись — почти совпадение', () {
    expect(scoreOf('DeadCells_Saves', needle('dead cells')), 55);
    expect(scoreOf('Cells of the Dead', needle('dead cells')), 55);
  });

  test('часть слов — слабая догадка, но догадка', () {
    expect(scoreOf('witcher saves', needle('the witcher wild hunt')), 30);
  });

  test('пустому сравнивать нечего', () {
    expect(scoreOf('', needle('hollow knight')), 0);
    expect(scoreOf('Hollow Knight', ''), 0);
  });
}
