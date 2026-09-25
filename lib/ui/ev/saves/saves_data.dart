import 'package:flutter/foundation.dart';

import '../data/sample_data.dart';

/// Состояние раздела «Сохранения» — те же четыре, что в прототипе.
enum EvSavesState {
  synced('Всё синхронизировано', 'обычная лента'),
  conflict('Конфликт версий', 'две ветки, нужен выбор'),
  uploading('Выгрузка идёт', '62 % текущей точки'),
  noCloud('Облако недоступно', 'копим локально');

  const EvSavesState(this.label, this.hint);

  final String label;
  final String hint;
}

/// Где живут сохранения: этот компьютер, второе устройство, хранилище.
@immutable
class EvDevice {
  const EvDevice({
    required this.name,
    required this.detail,
    required this.icon,
    required this.short,
    this.os,
    this.seen,
    this.online = false,
    this.here = false,
  });

  /// «ПК · КУЗНЯ».
  final String name;

  /// «Windows 11 · этот компьютер».
  final String detail;

  final String icon;

  /// Как устройство подписано в ленте: «КУЗНЯ».
  final String short;

  /// Система: «Windows 11». У хранилища её нет.
  final String? os;

  /// Когда было в сети последний раз: «2 часа назад». Этот компьютер
  /// в сети всегда.
  final String? seen;

  final bool online;

  /// Этот компьютер.
  final bool here;

  EvDevice copyWith({String? detail, bool? online}) => EvDevice(
    name: name,
    detail: detail ?? this.detail,
    icon: icon,
    short: short,
    os: os,
    seen: seen,
    online: online ?? this.online,
    here: here,
  );
}

/// Чем помечена точка в ленте.
enum EvSaveMark {
  /// Ушло в облако.
  synced,

  /// Две ветки разошлись.
  conflict,

  /// Выгружается прямо сейчас.
  uploading,

  /// Лежит локально и ждёт очереди.
  waiting,
}

/// Точка в ленте сохранений.
@immutable
class EvSavePoint {
  const EvSavePoint({
    required this.game,
    required this.where,
    required this.ago,
    this.at,
    required this.device,
    required this.note,
    this.mark = EvSaveMark.synced,
    this.progress,
  });

  /// Игра из библиотеки — от неё название.
  final SampleGame game;

  /// Где вы в ней остановились: «Глава 5 «Кузня Сумерек»».
  final String where;

  /// Сколько прошло: «6 мин», «1 ч 20 мин», «3 дня».
  final String ago;

  /// Когда именно — если «сколько прошло» уже не читается: «вчера,
  /// 23:41». Лента показывает это, а приборы — всё равно [ago].
  final String? at;

  final EvDevice device;

  /// «автосохранение · 148 МБ».
  final String note;

  final EvSaveMark mark;

  /// Ход выгрузки 0…1 — только у той точки, которая уходит сейчас.
  final double? progress;

  String get title => '${game.title} · $where';

  /// Как точка подписана в ленте.
  String get stamp => at ?? '$ago назад';
}

/// Одна из двух разошедшихся версий.
@immutable
class EvConflictSide {
  const EvConflictSide({
    required this.device,
    required this.when,
    required this.ago,
    required this.facts,
  });

  final EvDevice device;

  /// «Сегодня, 02:14».
  final String when;

  /// Сколько прошло: «6 мин».
  final String ago;

  /// Четыре пары «что» — «сколько».
  final List<(String, String)> facts;
}

/// Расхождение сохранений: не ошибка, а выбор. Поэтому стороны стоят
/// рядом и каждая показывает одни и те же четыре факта.
@immutable
class EvSaveConflict {
  const EvSaveConflict({
    required this.game,
    required this.title,
    required this.detail,
    required this.mine,
    required this.theirs,
    required this.note,
  });

  final SampleGame game;

  /// «Глубина 9 — два расхождения сохранения».
  final String title;

  /// Почему слить автоматически нельзя.
  final String detail;

  /// Версия с этого компьютера — она стоит первой и подсвечена.
  final EvConflictSide mine;

  final EvConflictSide theirs;

  /// Что будет с отклонённой версией.
  final String note;
}

/// Всё, что раздел показывает в одном состоянии.
@immutable
class EvSaves {
  const EvSaves({
    required this.usedGb,
    required this.quotaGb,
    required this.rollbacks,
    required this.devices,
    required this.points,
    required this.conflict,
    this.cloudReachable = true,
    this.uploadQueue = 0,
    this.uploadDone = 0,
  });

  /// Занято в облаке и сколько его всего.
  final double usedGb;
  final double quotaGb;

  /// Точек отката во всех играх.
  final int rollbacks;

  final List<EvDevice> devices;

  /// Лента сверху вниз, от свежего к старому.
  final List<EvSavePoint> points;

  /// `null` — расхождений нет.
  final EvSaveConflict? conflict;

  /// Облако отвечает. Нет — лента прячется, копим локально.
  final bool cloudReachable;

  /// Сколько точек ждёт выгрузки и сколько уже ушло.
  final int uploadQueue;
  final int uploadDone;

  /// Доля занятого 0…1. Полоса и надпись над ней — одно и то же число.
  double get fill => usedGb / quotaGb;

  /// Игр под защитой — те, в которых вы играли: у остальных сохранять
  /// нечего. Число выводится из библиотеки, а не пишется рядом.
  int get protected => [
    for (final g in sampleLibrary)
      if (g.played > Duration.zero) g,
  ].length;

  /// Сколько ждёт решения. Ноль — раздел не просит ничего решать.
  int get conflicts => conflict == null ? 0 : 1;

  /// Когда была последняя выгрузка — это верхняя *уже ушедшая* точка
  /// ленты, а не отдельное число рядом. Та, что уходит прямо сейчас,
  /// ещё не выгружена.
  String get lastUpload {
    for (final p in points) {
      if (p.mark == EvSaveMark.synced) return p.ago;
    }
    return '—';
  }
}
