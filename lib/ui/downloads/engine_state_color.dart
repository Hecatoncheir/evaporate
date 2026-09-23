import 'package:flutter/material.dart';

import '../../services/download/download_engine.dart';
import '../theme.dart';

/// Цвет состояния движка загрузок и то, мигает ли его светодиод.
///
/// Одинаковый `switch` стоял в плашке на странице загрузок и в строке
/// состояния внизу окна: состояние одно, и покрасить его в двух местах
/// по-разному значило бы сказать о нём две разные вещи.
extension EngineStateColor on EvaporatePalette {
  Color engine(EngineState state) => switch (state) {
    EngineState.ready => accent,
    EngineState.starting => warning,
    EngineState.failed => danger,
    EngineState.stopped => textSecondary,
  };
}

extension EngineStateBlink on EngineState {
  /// Светодиод мигает, только пока движок поднимается или сломан: ровно
  /// горящая точка рядом со словом «готов» ничего не добавляет.
  bool get blinks => this == EngineState.starting || this == EngineState.failed;
}
