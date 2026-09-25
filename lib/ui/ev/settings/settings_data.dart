import 'package:flutter/foundation.dart';

import '../data/sample_data.dart';
import '../widgets/ev_game_card.dart';

/// Клавиша приложения: что делает, зачем и какими кнопками. Таблица
/// в «Настройках → Клавиши» и строка подсказок внизу окна берут клавиши
/// отсюда — поэтому они не могут разойтись.
@immutable
class EvKeyBinding {
  const EvKeyBinding(this.name, this.detail, this.keys, {this.hint});

  final String name;
  final String detail;
  final List<String> keys;

  /// Подпись в строке подсказок, если клавиша там есть.
  final String? hint;
}

/// Клавиши — как `KEYS` в прототипе. Первые пять стоят и в строке
/// подсказок, под короткими подписями.
const evKeyBindings = [
  EvKeyBinding('Навигация по сетке', 'Перемещение между обложками и строками', [
    '↑',
    '↓',
    '←',
    '→',
  ], hint: 'Навигация'),
  EvKeyBinding('Выбрать', 'Открывает карточку игры', [
    'Enter',
  ], hint: 'Выбрать'),
  EvKeyBinding('Назад', 'Закрывает карточку, диалог или страницу друга', [
    'Esc',
  ], hint: 'Назад'),
  EvKeyBinding('Следующий раздел', 'По кругу: библиотека → … → профиль', [
    'Ctrl',
    'Tab',
  ], hint: 'Разделы'),
  EvKeyBinding('Поиск и команды', 'Игры, разделы и действия в одном списке', [
    '/',
  ], hint: 'Поиск'),
  EvKeyBinding('Раздел по номеру', '1 библиотека · 6 профиль', ['1', '…', '6']),
  EvKeyBinding('Запустить выбранное', 'Из поиска, минуя карточку', [
    'Shift',
    'Enter',
  ]),
  EvKeyBinding('Оверлей поверх игры', 'Работает, пока игра запущена', [
    'Shift',
    'Tab',
  ]),
  EvKeyBinding('Скриншот', 'Сохраняется рядом с игрой', ['F12']),
  EvKeyBinding('Пауза загрузки под курсором', 'В разделе «Загрузки»', [
    'Space',
  ]),
];

/// Подсказки нижней строки — из той же таблицы. Стрелки там одной
/// клавишей: «↑↓←→».
List<(String, String)> get evHints => [
  for (final k in evKeyBindings)
    if (k.hint != null)
      (k.keys.length == 4 ? k.keys.join() : k.keys.join('+'), k.hint!),
];

/// Папка с играми на диске. Игры в ней — из библиотеки, занятость —
/// весь диск, а не только игры: иначе полоса врала бы.
@immutable
class EvDrive {
  const EvDrive({
    required this.path,
    required this.capacityGb,
    required this.freeGb,
    required this.games,
    this.readOnly = false,
    this.installsHere = false,
  });

  final String path;
  final double capacityGb;
  final double freeGb;
  final List<SampleGame> games;
  final bool readOnly;

  /// Сюда ставится новое.
  final bool installsHere;

  /// Занято на диске всего, 0…1.
  double get used => 1 - freeGb / capacityGb;

  /// Сколько на диске занимают игры: установленные целиком, качающиеся —
  /// уже полученной частью.
  double get gamesGb => games.fold(0, (sum, g) => sum + evOnDiskGb(g));
}

/// Сколько игра занимает на диске прямо сейчас, ГБ.
double evOnDiskGb(SampleGame g) {
  final total = double.tryParse(g.size.split(' ').first) ?? 0;
  return switch (g.state) {
    EvGameState.ready => total,
    EvGameState.downloading => total * (g.progress ?? 0),
    EvGameState.queued => 0,
  };
}

/// Что раздавать до какого рейтинга.
enum EvSeedLimit {
  one('1.0'),
  two('2.0'),
  none('Без предела');

  const EvSeedLimit(this.label);
  final String label;
}

/// Всё, что человек выбирает в «Настройках». Движка нет, поэтому большая
/// часть — просто запомненный выбор; облик и эффекты живут в своих
/// моделях, потому что их читает всё приложение.
class EvSettings extends ChangeNotifier {
  EvSettings();

  /// Предел приёма в серые часы расписания, МБ/с.
  static const limitMb = 2;

  /// Предел отдачи, пока идёт игра, МБ/с.
  static const inGameUploadMb = 1;

  /// Предел приёма, пока идёт игра, МБ/с: загрузки не отнимают у неё сеть.
  static const inGameDownloadMb = 1;

  /// Порт входящих соединений.
  static const port = 51413;

  static const version = '3.1.0';
  static const engineVersion = '2.8.4';

  /// Расписание скорости: для каждого часа — без ограничения или нет.
  /// Ночь (0–7) открыта: канал всё равно простаивает.
  List<bool> get schedule => List.unmodifiable(_schedule);
  final _schedule = [for (var h = 0; h < 24; h++) h < 8];

  void setHour(int hour, bool unlimited) {
    if (_schedule[hour] == unlimited) return;
    _schedule[hour] = unlimited;
    notifyListeners();
  }

  final _choices = <String, Object>{
    'density': 'Обычно',
    'covers': 'Генерировать',
    'slots': 3,
    'afterDownload': 'Установить',
    'seedLimit': EvSeedLimit.two,
    'saveEvery': '5 мин',
    'keepPoints': '50',
    'onClose': 'Свернуть в трей',
    'updates': 'Автоматически',
  };

  final _switches = <String, bool>{
    'scan': true,
    'encryption': true,
    'stopSeeding': false,
    'friendsUnlimited': true,
    'cloud': true,
    'autostart': true,
    'awake': true,
  };

  /// Выбранный вариант строки с сегментами.
  T choice<T extends Object>(String key) => _choices[key]! as T;

  void choose(String key, Object value) {
    if (_choices[key] == value) return;
    _choices[key] = value;
    notifyListeners();
  }

  bool on(String key) => _switches[key]!;

  void toggle(String key, bool value) {
    if (_switches[key] == value) return;
    _switches[key] = value;
    notifyListeners();
  }

  /// Одновременных загрузок — это же число стоит в «Загрузках»
  /// и в правой колонке библиотеки: «2 / 3».
  int get slots => choice<int>('slots');
}

/// Папки с играми: новое ставится на D, архив на E только читается.
/// Какая игра где — по библиотеке: всё, что качается и ждёт, едет на D.
List<EvDrive> sampleDrivesFor(List<SampleGame> library) {
  const archive = {
    'Лунная Колея',
    'Стеклянный Сад',
    'Тихий Порог',
    'Глубина 9',
  };
  return [
    EvDrive(
      path: r'D:\Игры',
      capacityGb: 500,
      freeGb: 214,
      installsHere: true,
      games: [
        for (final g in library)
          if (!archive.contains(g.title)) g,
      ],
    ),
    EvDrive(
      path: r'E:\Архив\Игры',
      capacityGb: 440,
      freeGb: 52,
      readOnly: true,
      games: [
        for (final g in library)
          if (archive.contains(g.title)) g,
      ],
    ),
  ];
}

/// Диски для образца — по библиотеке образца.
final sampleDrives = sampleDrivesFor(sampleLibrary);
