import '../saves/saves_data.dart';
import '../widgets/ev_icon.dart';
import 'sample_data.dart';

// Содержимое раздела «Сохранения» — то же, что в прототипе. Игры берутся
// из библиотеки, устройства — общие для ленты и разбора расхождения,
// поэтому колонка «ПК · КУЗНЯ» в разборе и метка «КУЗНЯ» в ленте
// не могут разойтись.

SampleGame _game(String title) =>
    sampleLibrary.firstWhere((g) => g.title == title);

const evThisPc = EvDevice(
  name: 'ПК · КУЗНЯ',
  detail: 'Windows 11 · этот компьютер',
  icon: EvIcons.desktop,
  short: 'КУЗНЯ',
  os: 'Windows 11',
  online: true,
  here: true,
);

const evLaptop = EvDevice(
  name: 'Ноутбук · ДОРОГА',
  detail: 'Linux · 2 часа назад',
  icon: EvIcons.laptop,
  short: 'ДОРОГА',
  os: 'Linux',
  seen: '2 часа назад',
);

const evVault = EvDevice(
  name: 'Хранилище',
  detail: 'Шифрование на устройстве · AES-256',
  icon: EvIcons.cloud,
  short: 'облако',
  online: true,
);

const _devices = [evThisPc, evLaptop, evVault];

/// Расхождение в «Глубине 9»: игра шла на двух устройствах сразу.
final _conflict = EvSaveConflict(
  game: _game('Глубина 9'),
  title: 'Глубина 9 — два расхождения сохранения',
  detail:
      'Игра шла на двух устройствах без синхронизации между ними. Слить '
      'автоматически нельзя: прогресс разошёлся на уровне 5.',
  mine: const EvConflictSide(
    device: evThisPc,
    when: 'Сегодня, 02:14',
    ago: '6 мин',
    facts: [
      ('Прогресс', 'Уровень 6 · 62 %'),
      ('В игре', '64 ч 12 мин'),
      ('Кислород', '41 %'),
      ('Размер', '148 МБ'),
    ],
  ),
  theirs: const EvConflictSide(
    device: evLaptop,
    when: 'Вчера, 23:41',
    ago: '2 ч 33 мин',
    facts: [
      ('Прогресс', 'Уровень 5 · 88 %'),
      ('В игре', '63 ч 47 мин'),
      ('Кислород', '73 %'),
      ('Размер', '141 МБ'),
    ],
  ),
  note: 'Отклонённая версия уйдёт в корзину и будет храниться 30 дней',
);

/// Лента: от свежего к старому. Точка «Глубины 9» описывает ту ветку,
/// на которую показывает её устройство, — иначе она рассказывала бы
/// про один компьютер числами другого.
List<EvSavePoint> _points({required bool conflicted}) => [
  EvSavePoint(
    game: _game('Пепельный Предел'),
    where: 'Глава 5 «Кузня Сумерек»',
    ago: '6 мин',
    device: evThisPc,
    note: 'автосохранение · 148 МБ',
  ),
  EvSavePoint(
    game: _game('Красный Меридиан'),
    where: 'Кампания «Излом», ход 42',
    ago: '1 ч 20 мин',
    device: evThisPc,
    note: 'ручное · 22 МБ',
  ),
  EvSavePoint(
    game: _game('Глубина 9'),
    where: 'Уровень 5, кислород 73 %',
    ago: '2 ч 33 мин',
    at: 'вчера, 23:41',
    device: evLaptop,
    note: conflicted
        ? 'две ветки · выберите, какую оставить'
        : 'автосохранение · 141 МБ',
    mark: conflicted ? EvSaveMark.conflict : EvSaveMark.synced,
  ),
  EvSavePoint(
    game: _game('Волчья Тропа'),
    where: 'Зимовье у Чёрной реки',
    ago: '5 ч 12 мин',
    at: 'вчера, 19:08',
    device: evLaptop,
    note: 'автосохранение · 310 МБ',
  ),
  EvSavePoint(
    game: _game('Стеклянный Сад'),
    where: 'Комната 88',
    ago: '3 дня',
    device: evThisPc,
    note: 'ручное · 4 МБ',
  ),
];

/// Что показывает раздел в каждом из четырёх состояний.
EvSaves sampleSavesFor(EvSavesState state) {
  final conflicted = state == EvSavesState.conflict;
  final points = _points(conflicted: conflicted);
  return EvSaves(
    usedGb: 4.1,
    quotaGb: 20,
    rollbacks: 248,
    devices: state == EvSavesState.noCloud
        ? [evThisPc, evLaptop, evVault.copyWith(online: false)]
        : _devices,
    points: switch (state) {
      // Верхняя точка уходит в облако прямо сейчас. «Последней
      // выгрузкой» она ещё не стала: та — следующая за ней.
      EvSavesState.uploading => [
        EvSavePoint(
          game: points.first.game,
          where: points.first.where,
          ago: points.first.ago,
          at: 'сейчас',
          device: evThisPc,
          note: '92 МБ из 148 МБ',
          mark: EvSaveMark.uploading,
          progress: .62,
        ),
        ...points.skip(1),
      ],
      // Облако не отвечает — лента не показывается совсем: она про то,
      // что ушло, а сейчас не уходит ничего.
      EvSavesState.noCloud => const [],
      _ => points,
    },
    conflict: conflicted ? _conflict : null,
    cloudReachable: state != EvSavesState.noCloud,
    uploadQueue: switch (state) {
      EvSavesState.uploading => 5,
      EvSavesState.noCloud => 5,
      _ => 0,
    },
    uploadDone: state == EvSavesState.uploading ? 2 : 0,
  );
}
