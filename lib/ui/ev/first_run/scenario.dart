import 'package:flutter/foundation.dart';

/// Сценарий, который листается полосой внизу окна: первый запуск,
/// возвращение. Полоса и стрелки `←` `→` не знают, какой из них идёт.
abstract class EvScenario implements Listenable {
  /// Номер шага; `null` — сценарий не идёт.
  int? get index;

  int get count;

  String get title;

  String get detail;

  void next();

  void previous();

  void exit();
}

/// Шаг сценария «Возвращение».
typedef EvReturnStep = (String title, String detail);

/// Возвращение: четыре шага от новостей до продолжения с той же секунды.
class EvReturnController extends ChangeNotifier implements EvScenario {
  EvReturnController({required this.onStep, this.onExit});

  static const steps = <EvReturnStep>[
    (
      'Открыли на следующий день',
      'пять событий за ночь · герой помнит точку остановки',
    ),
    ('Заглянули в загрузки из дайджеста', 'одно действие прямо из новости'),
    ('Дайджест разобран', 'свернулся в плашку топбара · можно вернуть'),
    ('Продолжили с того же места', 'удержание · ритуал · Глава 5, 02:14'),
  ];

  final void Function(int step) onStep;
  final VoidCallback? onExit;

  int? _index;

  @override
  int? get index => _index;

  @override
  int get count => steps.length;

  @override
  String get title => steps[_index ?? 0].$1;

  @override
  String get detail => steps[_index ?? 0].$2;

  void go(int step) {
    _index = step.clamp(0, count - 1);
    notifyListeners();
    onStep(_index!);
  }

  /// С последнего шага — заново.
  @override
  void next() => go(_index == null || _index == count - 1 ? 0 : _index! + 1);

  @override
  void previous() {
    final i = _index;
    if (i != null && i > 0) go(i - 1);
  }

  @override
  void exit() {
    if (_index == null) return;
    _index = null;
    notifyListeners();
    onExit?.call();
  }
}
