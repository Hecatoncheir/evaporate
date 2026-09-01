/// Приведение имени раздачи к названию игры.
///
/// Торренты называются не так, как игры: `The.Witcher.3.Wild.Hunt.GOTY.
/// MULTi15-ElAmigos`. Прежде чем что-то искать, из имени нужно убрать
/// версии, теги релиз-групп и пометки о языках.
class ReleaseName {
  const ReleaseName._();

  /// Метки, которые к названию игры отношения не имеют.
  static const _noiseWords = {
    'repack',
    'rip',
    'proper',
    'multi',
    'incl',
    'dlc',
    'dlcs',
    'update',
    'crack',
    'cracked',
    'fix',
    'goty',
    'edition',
    'deluxe',
    'complete',
    'definitive',
    'remastered',
    'directors',
    'cut',
    'anniversary',
    'gog',
    'codex',
    'plaza',
    'skidrow',
    'reloaded',
    'razor1911',
    'fitgirl',
    'dodi',
    'elamigos',
    'empress',
    'tenoke',
    'rune',
    'hoodlum',
    'flt',
    'steampunks',
    'x64',
    'x86',
    'win64',
    'win32',
    'pc',
    'portable',
    'iso',
    'rus',
    'eng',
    'multi2',
    'multi5',
    'multi6',
    'multi7',
    'multi9',
    'multi10',
    'multi11',
    'multi12',
    'multi15',
  };

  /// Слова, после которых всё остальное — точно не название.
  static const _cutMarkers = {'repack', 'rip', 'incl', 'crack', 'update'};

  /// `Hollow.Knight.v1.5.78-GOG` -> `Hollow Knight`.
  static String clean(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return '';

    // Расширение образа или архива.
    text = text.replaceFirst(
      RegExp(r'\.(iso|rar|zip|7z|torrent)$', caseSensitive: false),
      '',
    );

    // Всё в скобках — годы, языки, названия групп.
    text = text.replaceAll(RegExp(r'[\[\(\{][^\]\)\}]*[\]\)\}]'), ' ');

    // Подчёркивание — словесный символ, поэтому «_v1.6.9» не даёт границы
    // слова и версия распознаётся лишь наполовину. Меняем его на пробел
    // заранее, а точки трогаем уже после разбора версий.
    text = text.replaceAll(RegExp(r'[_+]+'), ' ');

    // Версии снимаем до замены точек: иначе «v1.5.78» превратится
    // в «v1 5 78», и от версии останутся числа посреди названия.
    text = text.replaceAll(
      RegExp(r'\bv?\d+(\.\d+)+\b', caseSensitive: false),
      ' ',
    );
    text = text.replaceAll(RegExp(r'\bv\d+\b', caseSensitive: false), ' ');
    text = text.replaceAll(
      RegExp(r'[._]?\b(build|update|patch)[._\s]*\d+\b', caseSensitive: false),
      ' ',
    );

    // Теперь точки — тоже разделители. Дефис не трогаем: он часто отделяет
    // группу, но встречается и в названиях игр.
    text = text.replaceAll(RegExp(r'[.]+'), ' ');

    // Хвост после дефиса — обычно релиз-группа: `... Hunt-ElAmigos`.
    text = text.replaceAll(RegExp(r'\s*-\s*[A-Za-z0-9]+\s*$'), ' ');

    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final kept = <String>[];
    for (final word in words) {
      final plain = word.toLowerCase().replaceAll(
        RegExp(r'[^a-zа-я0-9]', unicode: true),
        '',
      );
      if (plain.isEmpty) continue;
      // После такого слова идёт описание релиза, а не название игры.
      if (_cutMarkers.contains(plain)) break;
      if (_noiseWords.contains(plain)) continue;
      kept.add(word);
    }

    return kept
        .join(' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAll(RegExp(r'^[\s\-]+|[\s\-]+$'), '')
        .trim();
  }

  /// Насколько найденное название похоже на искомое: 0..1.
  ///
  /// Нужна не идеальная метрика, а способ отсеять явно чужие результаты
  /// и понять, стоит ли предлагать замену без подтверждения.
  static double similarity(String a, String b) {
    final left = _tokens(a);
    final right = _tokens(b);
    if (left.isEmpty || right.isEmpty) return 0;
    if (left.join(' ') == right.join(' ')) return 1;

    final common = left.where(right.contains).length;
    return (2 * common) / (left.length + right.length);
  }

  static List<String> _tokens(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-zа-я0-9\s]', unicode: true), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
}
