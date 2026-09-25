import 'package:flutter/foundation.dart';

import '../data/sample_data.dart';
import '../util/units.dart';
import '../widgets/ev_surfaces.dart';

/// Состояние раздела «Загрузки» — те же шесть, что `DL` в прототипе.
///
/// Движка раздач нет, поэтому состояние переключает «Настройки →
/// Разработка», как панель состояний в прототипе. «Сеть пропала» — не
/// свойство очереди, а свойство окна: его же видит герой, поэтому эти два
/// состояния ходят парой.
enum EvDownloadsState {
  active('Две активные', 'нормальный ход'),
  noSeeds('Нет раздающих', '0 сидов, ждём'),
  noSpace('Нет места на диске', 'не хватает 6.2 ГБ'),
  hash('Ошибка проверки', '12 частей повреждены'),
  offline('Сеть пропала', 'авто-пауза с отсчётом'),
  empty('Очередь пуста', 'нечего качать');

  const EvDownloadsState(this.label, this.hint);

  final String label;
  final String hint;
}

/// Почему раздача выделена. Цвет кодирует причину, а не громкость:
/// [warn] — ждём внешнего, [err] — нужно решение человека, [arc] — идёт
/// работа с данными, [idle] — просто пауза.
enum EvTorrentTone { none, warn, err, arc, idle }

/// Кнопка в полосе разбора.
@immutable
class EvAlertAction {
  const EvAlertAction(this.label, this.icon, {this.primary = false});

  final String label;
  final String icon;

  /// Главное действие строки — крупнее и первым.
  final bool primary;
}

/// Полоса разбора внутри раздачи: что случилось, почему и что с этим
/// делать. Не «ошибка», а разбор: сначала причина, потом выход.
@immutable
class EvTorrentAlert {
  const EvTorrentAlert({
    required this.tone,
    required this.icon,
    required this.title,
    required this.detail,
    required this.actions,
  });

  final EvTorrentTone tone;
  final String icon;
  final String title;
  final String detail;
  final List<EvAlertAction> actions;
}

/// Как части раздачи разложены по состояниям. Кольцо и подписи читают
/// одни и те же гигабайты, поэтому разойтись не могут: проценты кольца
/// считаются из них, а не пишутся рядом вторым числом.
@immutable
class EvSwarmParts {
  const EvSwarmParts({
    required this.received,
    required this.inFlight,
    required this.verifying,
    required this.remaining,
  });

  /// Получено и проверено.
  final double received;

  /// Части в работе прямо сейчас.
  final double inFlight;

  /// Пришло, но ещё не сверено.
  final double verifying;

  /// Ещё не запрошено.
  final double remaining;

  double get total => received + inFlight + verifying + remaining;

  /// Доля готового, 0…1.
  double get progress => received / total;
}

/// Раздача в списке «Сейчас качается».
@immutable
class EvTorrent {
  const EvTorrent({
    required this.game,
    required this.name,
    required this.path,
    required this.parts,
    required this.downKb,
    required this.upKb,
    required this.peakKb,
    required this.seeds,
    required this.peers,
    required this.eta,
    this.paused = false,
    this.tone = EvTorrentTone.none,
    this.bar = EvBarTone.hot,
    this.alert,
  });

  /// Игра из библиотеки: от неё обложка, название и размер.
  final SampleGame game;

  /// Имя раздачи на трекере — не название игры.
  final String name;

  /// Куда кладётся и откуда взято.
  final String path;

  final EvSwarmParts parts;

  /// Приём и отдача, КБ/с. `null` — измерять нечего: сети нет.
  final int? downKb;
  final int? upKb;

  /// Пик приёма этой раздачи, КБ/с.
  final int peakKb;

  final int seeds;
  final int peers;

  /// «осталось 7 ч 59 мин», «пауза», «время не определено».
  final String eta;

  final bool paused;
  final EvTorrentTone tone;
  final EvBarTone bar;
  final EvTorrentAlert? alert;

  double get progress => parts.progress;

  /// Раздача считается активной, пока её не остановили.
  bool get active => !paused;

  EvTorrent copyWith({
    String? name,
    EvSwarmParts? parts,
    int? downKb,
    int? upKb,
    int? seeds,
    int? peers,
    String? eta,
    bool? paused,
    EvTorrentTone? tone,
    EvBarTone? bar,
    EvTorrentAlert? alert,
    bool noRates = false,
    bool noAlert = false,
  }) => EvTorrent(
    game: game,
    name: name ?? this.name,
    path: path,
    parts: parts ?? this.parts,
    downKb: noRates ? null : (downKb ?? this.downKb),
    upKb: noRates ? null : (upKb ?? this.upKb),
    peakKb: peakKb,
    seeds: seeds ?? this.seeds,
    peers: peers ?? this.peers,
    eta: eta ?? this.eta,
    paused: paused ?? this.paused,
    tone: tone ?? this.tone,
    bar: bar ?? this.bar,
    alert: noAlert ? null : (alert ?? this.alert),
  );
}

/// Раздача в очереди: ждёт свободного слота.
@immutable
class EvQueued {
  const EvQueued(this.name, this.game);

  /// Имя раздачи на трекере.
  final String name;

  /// Игра из библиотеки — от неё размер.
  final SampleGame game;

  String get line => '$name · ${game.size}';
}

/// Всё, что раздел показывает в одном состоянии.
@immutable
class EvDownloads {
  const EvDownloads({
    required this.torrents,
    required this.queue,
    required this.slots,
    required this.peakKb,
    required this.toDiskShare,
  });

  final List<EvTorrent> torrents;
  final List<EvQueued> queue;

  /// Сколько раздач может идти одновременно.
  final int slots;

  /// Пик приёма за час, КБ/с.
  final int peakKb;

  /// Какая доля приёма уже легла на диск. Меньше единицы: часть частей
  /// ещё сверяется в памяти. Отдельным числом не пишется — иначе оно
  /// разошлось бы с приёмом.
  final double toDiskShare;

  int get toDiskKb => (downKb * toDiskShare).round();

  /// Приём — сумма по раздачам. Отдельным числом нигде не пишется.
  int get downKb => torrents.fold(0, (sum, t) => sum + (t.downKb ?? 0));

  /// Отдача — тоже сумма, по тому же правилу.
  int get upKb => torrents.fold(0, (sum, t) => sum + (t.upKb ?? 0));

  int get active => torrents.where((t) => t.active).length;

  /// Очередь при другом пределе одновременных загрузок. Лишние идущие
  /// раздачи встают в начало очереди — как у движка, — а не остаются
  /// идти сверх предела: «2 / 1» было бы враньём.
  EvDownloads withSlots(int limit) {
    if (limit == slots && active <= limit) return this;
    var running = 0;
    final kept = <EvTorrent>[];
    final waiting = <EvQueued>[];
    for (final t in torrents) {
      if (t.active && running >= limit) {
        waiting.add(EvQueued(t.name, t.game));
        continue;
      }
      if (t.active) running++;
      kept.add(t);
    }
    return EvDownloads(
      torrents: kept,
      queue: [...waiting, ...queue],
      slots: limit,
      peakKb: peakKb,
      toDiskShare: toDiskShare,
    );
  }

  /// Очередь, пока идёт игра: приём и отдача ужаты до предела, каждая
  /// раздача — в своей доле, а время до конца — от новой скорости.
  /// Иначе верхняя полоса писала бы «1.0 МБ/с», а раздачи под ней —
  /// 592 КБ/с и 1.03 МБ/с, как в оверлее прототипа.
  EvDownloads capped({required int downKb, required int upKb}) {
    final down = this.downKb, up = this.upKb;
    if (down <= downKb && up <= upKb) return this;
    int share(int? kb, int sum, int cap) =>
        sum <= cap ? kb ?? 0 : ((kb ?? 0) * cap / sum).round();
    EvTorrent cap(EvTorrent t) {
      if (!t.active || t.downKb == null) return t;
      final kb = share(t.downKb, down, downKb);
      return t.copyWith(
        downKb: kb,
        upKb: share(t.upKb, up, upKb),
        eta: formatEta(t.parts.total - t.parts.received, kb),
      );
    }

    return EvDownloads(
      torrents: [for (final t in torrents) cap(t)],
      queue: queue,
      slots: slots,
      peakKb: peakKb,
      toDiskShare: toDiskShare,
    );
  }

  /// Кольцо показывает ту раздачу, которая принимает; если такой нет —
  /// первую в списке.
  EvSwarmParts? get parts => torrents.isEmpty
      ? null
      : torrents
            .firstWhere((t) => t.active, orElse: () => torrents.first)
            .parts;
}
