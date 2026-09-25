import '../downloads/download_data.dart';
import '../widgets/ev_icon.dart';
import '../widgets/ev_surfaces.dart';
import '../util/units.dart';
import 'sample_data.dart';

// Содержимое раздела «Загрузки» — то же, что `DL` в прототипе. Раздачи
// стоят на играх из библиотеки: обложка, размер и версия берутся оттуда,
// а имя раздачи и путь — свои, потому что на трекере они свои.

SampleGame _game(String title) =>
    sampleLibrary.firstWhere((g) => g.title == title);

/// «Орбита 7» — 28.8 ГБ в раздаче: на диск она развернётся в 36.0 ГБ,
/// которые показывает библиотека.
final _orbita = EvTorrent(
  game: _game('Орбита 7'),
  name: 'orbita-7 · Полное издание [RU+ENG] (2026) v5.2 + 3 DLC',
  path: r'D:\Игры\Orbita7\ · 24 файла · rutracker-6904761',
  parts: const EvSwarmParts(
    received: 11.8,
    inFlight: 4.9,
    verifying: 2.6,
    remaining: 9.5,
  ),
  downKb: 592,
  upKb: 1600,
  peakKb: 7000,
  seeds: 27,
  peers: 31,
  // Из остатка и скорости: 17 ГБ на 592 КБ/с — почти восемь часов,
  // а не «4 ч 12 мин», как стояло в прототипе.
  eta: formatEta(28.8 - 11.8, 592),
);

final _halcyon = EvTorrent(
  game: _game('Хальцион: Эхо'),
  name: 'neon-halcyon-echo · дополнение «Эхо» v1.0',
  path: r'D:\Игры\NeonHalcyon\dlc · 6 файлов · rutracker-6913022',
  parts: const EvSwarmParts(
    received: 6.2,
    inFlight: 1.1,
    verifying: .4,
    remaining: 1.7,
  ),
  downKb: 1030,
  upKb: 340,
  peakKb: 11000,
  seeds: 81,
  peers: 82,
  eta: 'осталось 51 мин',
  bar: EvBarTone.cool,
);

final _queue = [
  EvQueued('neon-halcyon · v1.9', _game('Неон Хальцион')),
  EvQueued('orbita-7 · дополнение «Перигей»', _game('Перигей')),
];

/// Пауза без сети: измерять нечего, поэтому вместо нулей — прочерки.
EvTorrent _paused(EvTorrent t) => t.copyWith(
  noRates: true,
  seeds: 0,
  peers: 0,
  paused: true,
  eta: 'пауза',
  tone: EvTorrentTone.idle,
  bar: EvBarTone.stall,
);

/// Что показывает раздел в каждом из шести состояний.
EvDownloads sampleDownloadsFor(EvDownloadsState state) {
  final torrents = switch (state) {
    EvDownloadsState.active => [_orbita, _halcyon],
    EvDownloadsState.noSeeds => [
      _orbita.copyWith(
        downKb: 0,
        upKb: 12,
        seeds: 0,
        peers: 4,
        eta: 'время не определено',
        tone: EvTorrentTone.warn,
        bar: EvBarTone.stall,
        alert: const EvTorrentAlert(
          tone: EvTorrentTone.warn,
          icon: EvIcons.seed,
          title: 'Ждём раздающих',
          detail:
              'Ни один из 27 известных сидов не в сети последние '
              '18 минут. Загрузка продолжится сама, как только кто-то '
              'появится.',
          actions: [
            EvAlertAction('Искать источники', EvIcons.search, primary: true),
            EvAlertAction('В очередь', EvIcons.pause),
          ],
        ),
      ),
      _halcyon,
    ],
    EvDownloadsState.noSpace => [
      _orbita.copyWith(
        downKb: 0,
        upKb: 0,
        eta: 'остановлено',
        paused: true,
        tone: EvTorrentTone.err,
        bar: EvBarTone.dead,
        alert: const EvTorrentAlert(
          tone: EvTorrentTone.err,
          icon: EvIcons.drive,
          title: 'На диске D: не хватает 6.2 ГБ',
          detail:
              'Для распаковки нужно 28.8 ГБ, свободно 22.6 ГБ. Освободите '
              'место или перенесите загрузку на другой диск — скачанное '
              'сохранится.',
          actions: [
            EvAlertAction('Выбрать диск', EvIcons.drive, primary: true),
            EvAlertAction('Что удалить', EvIcons.info),
          ],
        ),
      ),
      _halcyon,
    ],
    // Двенадцать частей не прошли проверку: они ушли из «получено»
    // обратно в «проверку», поэтому готово стало 38 %, а не 41 %.
    EvDownloadsState.hash => [
      _orbita.copyWith(
        parts: const EvSwarmParts(
          received: 10.9,
          inFlight: 4.9,
          verifying: 3.5,
          remaining: 9.5,
        ),
        downKb: 1200,
        eta: 'перепроверка 38 %',
        tone: EvTorrentTone.arc,
        bar: EvBarTone.arc,
        alert: const EvTorrentAlert(
          tone: EvTorrentTone.arc,
          icon: EvIcons.verified,
          title: '12 частей не прошли проверку',
          detail:
              'Данные от одного из пиров пришли повреждёнными. '
              'Повреждённые части помечены и качаются заново, остальное '
              'трогать не нужно.',
          actions: [
            EvAlertAction('Перекачать', EvIcons.retry, primary: true),
            EvAlertAction('Журнал', EvIcons.info),
          ],
        ),
      ),
      _halcyon,
    ],
    EvDownloadsState.offline => [
      _paused(_orbita).copyWith(
        alert: const EvTorrentAlert(
          tone: EvTorrentTone.idle,
          icon: EvIcons.wifiOff,
          title: 'Нет сети · пауза',
          detail:
              'Соединение пропало 2 минуты назад. Продолжим автоматически '
              'через 0:24 — отменять и перезапускать не нужно.',
          actions: [EvAlertAction('Повторить сейчас', EvIcons.retry)],
        ),
      ),
      _paused(_halcyon),
    ],
    EvDownloadsState.empty => const <EvTorrent>[],
  };
  return EvDownloads(
    torrents: torrents,
    // «Нечего качать» — значит и очереди нет: иначе раздел говорил бы
    // «ничего не качается» и тут же показывал две раздачи в очереди.
    queue: state == EvDownloadsState.empty ? const [] : _queue,
    slots: sampleDownloadSlots,
    peakKb: 11000,
    toDiskShare: .913,
  );
}
