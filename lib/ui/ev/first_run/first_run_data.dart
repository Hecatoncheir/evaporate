import 'package:flutter/foundation.dart';

import '../data/game_facts.dart';
import '../data/sample_data.dart';
import '../downloads/download_data.dart';
import '../library/hero_state.dart';
import '../util/units.dart';
import '../widgets/ev_icon.dart';
import '../widgets/ev_surfaces.dart';

/// Что с каталогом игр. Не состояние героя: пустой каталог — это вообще
/// без героя.
enum EvCatalog {
  normal('Обычный', 'двенадцать игр'),
  empty('Пусто · первый запуск', 'ни одной игры на диске'),
  reading('Чтение каталога', 'скелетон, первые 300 мс');

  const EvCatalog(this.label, this.hint);

  final String label;
  final String hint;

  /// Сколько читается каталог при старте.
  static const readTime = Duration(milliseconds: 300);
}

/// Восемь шагов первого запуска: от пустой библиотеки до запущенной игры.
enum EvFirstRunStep {
  installed('Лаунчер только что установлен', 'библиотека пуста · движок готов'),
  magnet(
    'Вставили magnet-ссылку',
    'движок разобрал раздачу и показал, что внутри',
  ),
  queued(
    'Загрузка встала в очередь',
    'первые части пошли, скорость ещё оценивается',
  ),
  downloading('Качается', ''),
  verifying('Проверка файлов', 'хеши сходятся, докачка идёт параллельно'),
  installing('Установка на диск', 'распаковка 41 % · можно свернуть окно'),
  firstGame(
    'Первая игра в библиотеке',
    'герой появился, кнопка ждёт удержания',
  ),
  launch('Первый запуск', 'ритуал · шесть стадий · интерфейс испаряется');

  const EvFirstRunStep(this.title, this.detail);

  final String title;

  /// Строка под заголовком. У «Качается» её нет: она считается из
  /// раздачи — см. [EvFirstRun.detail].
  final String detail;

  EvFirstRunStep? get next =>
      index + 1 < values.length ? values[index + 1] : null;

  EvFirstRunStep? get previous => index > 0 ? values[index - 1] : null;

  /// Библиотека ещё пуста.
  bool get empty => index <= verifying.index;

  /// Шаг показывает раздачу в «Загрузках».
  bool get downloads =>
      this == queued || this == downloading || this == verifying;
}

/// Первый запуск: какой шаг и что выбрано в диалоге. Всё, что видно на
/// шагах, считается отсюда, — размер раздачи в загрузках и в герое тот,
/// что человек выбрал галочками, а не всегда 68.4 ГБ.
@immutable
class EvFirstRun {
  const EvFirstRun(this.step, {this.gb});

  final EvFirstRunStep step;

  /// Сколько выбрано в диалоге, ГБ. `null` — как предлагает раздача.
  final double? gb;

  /// Первая игра — та, что в герое.
  static final game = sampleHero;

  static EvGameFacts get facts => EvGameFacts.of(game);

  /// Что раздача предлагает скачать: то, что карточка игры держит на
  /// диске, — игра, русская озвучка и текстуры.
  static double get offered =>
      facts.parts.where((p) => p.onDisk).fold(0, (sum, p) => sum + p.size);

  double get total => gb ?? offered;

  EvFirstRun at(EvFirstRunStep s) => EvFirstRun(s, gb: gb);

  EvFirstRun withGb(double value) => EvFirstRun(step, gb: value);

  /// Приём по фазам, КБ/с: разгон, ход, проверка параллельно с докачкой.
  static const _rates = {
    EvFirstRunStep.queued: (218, 0),
    EvFirstRunStep.downloading: (1420, 612),
    EvFirstRunStep.verifying: (1100, 1900),
  };

  /// Доля полученного по фазам.
  static const _done = {
    EvFirstRunStep.queued: 0.004,
    EvFirstRunStep.downloading: 0.41,
    EvFirstRunStep.verifying: 0.88,
  };

  /// Раздача на шагах 3–5. Время до конца — из остатка и скорости:
  /// в прототипе «4 ч 12 мин» стояло рядом с 1.42 МБ/с, на которых
  /// 40 ГБ качаются почти восемь часов.
  EvTorrent? get torrent {
    if (!step.downloads) return null;
    final (down, up) = _rates[step]!;
    final t = total;
    final got = t * _done[step]!;
    final verifying = step == EvFirstRunStep.verifying;
    final flight = step == EvFirstRunStep.queued ? 0.1 : t * .03;
    final checking = verifying ? t * .04 : 0.0;
    return EvTorrent(
      game: game,
      name: 'ashen-verge · ${game.title} ${game.version} [RU+ENG]',
      path: r'D:\Игры\AshenVerge\ · 118 421 файл · magnet 9f2c…a41b',
      parts: EvSwarmParts(
        received: got,
        inFlight: flight,
        verifying: checking,
        remaining: t - got - flight - checking,
      ),
      downKb: down,
      upKb: up,
      peakKb: 2100,
      seeds: 27,
      peers: 31,
      // Первые секунды скорость честно оценивается, а не подменяется
      // нулём или спиннером.
      eta: step == EvFirstRunStep.queued
          ? 'оцениваем скорость'
          : verifying
          ? 'проверка ${percent(_done[step]!)} %'
          : formatEta(t - got, down),
      bar: verifying ? EvBarTone.arc : EvBarTone.hot,
      alert: verifying
          ? EvTorrentAlert(
              tone: EvTorrentTone.arc,
              icon: EvIcons.verified,
              title: 'Проверяем целостность',
              detail:
                  'Хеши сходятся на ${percent(_done[step]!)} %. Проверка идёт '
                  'параллельно с докачкой — ждать отдельно не придётся.',
              actions: const [EvAlertAction('Журнал', EvIcons.info)],
            )
          : null,
    );
  }

  /// Строка под заголовком шага; у «Качается» — из раздачи.
  String get detail {
    if (step != EvFirstRunStep.downloading) return step.detail;
    final t = torrent!;
    return '${percent(t.progress)} % · ${formatGb(t.parts.received)} из '
        '${formatGb(total)} · ${t.eta}';
  }

  /// Герой первой игры: только что установлена, играть ещё не начинали.
  EvHeroContent get hero => EvHeroContent(
    eyebrow: 'Готово · установлена только что',
    blurb:
        'Первая игра в вашей библиотеке. Удерживайте «Играть» — 620 мс, '
        'чтобы запустить её не случайно.',
    chips: [
      ('Новое', true),
      (game.version, false),
      (formatGb(total), false),
      (game.genre, false),
    ],
  );

  /// Библиотека на этом шаге.
  List<SampleGame> get library => step.empty ? const [] : [game.fresh()];

  /// Строка в верхней полосе вместо «Движок готов».
  (String, EvStatus)? get engine => switch (step) {
    EvFirstRunStep.installed ||
    EvFirstRunStep.magnet => ('Каталог пуст', EvStatus.idle),
    EvFirstRunStep.queued => ('Разгоняемся', EvStatus.busy),
    EvFirstRunStep.verifying => (
      'Проверка ${percent(_done[step]!)} %',
      EvStatus.busy,
    ),
    _ => null,
  };
}
