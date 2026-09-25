import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'palette.dart';

/// Что делает главная клавиша: запускает игру или качает её.
///
/// Тон — не цвет, а смысл: заливка запуска горит огнём главного действия,
/// заливка загрузки — холодным цветом данных. Одна заливка на оба смысла
/// означала бы, что «Скачать» и «Играть» неотличимы, пока не прочтёшь
/// подпись.
enum LauncherTone { launch, download }

/// Облик главной клавиши (`LauncherActionButton`): заливки двух тонов,
/// торец клавиши загрузки, свет изнутри и ореол.
///
/// Своим расширением, а не полями палитры: градиент и ядро — облик одного
/// компонента, и в палитре корпуса им не место. Схемы расходятся данными:
/// ночью заливка — переход от янтаря к остывающему низу, ядро светится, а
/// клавиша окружена ореолом своего цвета; днём заливка плоская, ядра нет,
/// и клавиша стоит на обычной тени — светлый корпус не светится.
@immutable
class LauncherButtonTheme extends ThemeExtension<LauncherButtonTheme> {
  const LauncherButtonTheme({
    required this.launchFill,
    required this.downloadFill,
    required this.downloadDepth,
    required this.core,
    required this.haloRest,
    required this.haloLit,
  });

  /// Заливка клавиши запуска. Горячее — сверху: так на клавишу падает свет,
  /// а остывающий низ уходит к торцу.
  final LinearGradient launchFill;

  /// Заливка клавиши загрузки — цвет данных, а не запуска.
  final LinearGradient downloadFill;

  /// Торец клавиши загрузки. Клавиша запуска стоит на торце схемы
  /// (`EvaporatePalette.depth`): оранжевый край под голубой клавишей
  /// читался бы чужой деталью.
  final Color downloadDepth;

  /// Свет изнутри клавиши, со стороны значка.
  final RadialGradient core;

  /// Доля ореола в покое и под курсором или фокусом; ноль — ореола у
  /// материала нет, и клавиша стоит на обычной тени.
  final double haloRest;
  final double haloLit;

  /// Геометрия переходов одна на обе схемы: иначе смена схемы крутила бы
  /// свет по клавише, а не меняла его цвет.
  ///
  /// Переход идёт сверху вниз, а не по диагонали, как в прототипе: клавиша
  /// тянется по ширине подписи, и на диагонали хвост длинного слова
  /// («Остановить», «Продолжить») ложился на остывающий низ, где надпись
  /// не дотягивает до нормы. По вертикали надпись всегда в светлой середине.
  static const _fillFrom = Alignment.topCenter;
  static const _fillTo = Alignment.bottomCenter;
  static const _fillStops = [0.0, 0.58, 1.0];
  static const _coreCenter = Alignment(-0.56, 0);
  static const _coreRadius = 0.9;
  static const _coreStops = [0.0, 0.4, 0.72];

  static const arclight = LauncherButtonTheme(
    launchFill: LinearGradient(
      begin: _fillFrom,
      end: _fillTo,
      colors: [Color(0xFFFFC24D), Color(0xFFFF7A18), Color(0xFFC93A05)],
      stops: _fillStops,
    ),
    downloadFill: LinearGradient(
      begin: _fillFrom,
      end: _fillTo,
      colors: [Color(0xFFA9F2FF), Color(0xFF5EE7FF), Color(0xFF1B6F8A)],
      stops: _fillStops,
    ),
    downloadDepth: Color(0xFF12495C),
    core: RadialGradient(
      center: _coreCenter,
      radius: _coreRadius,
      colors: [Color(0xA3FFFFFF), Color(0x43FFD278), Color(0x00FFD278)],
      stops: _coreStops,
    ),
    haloRest: 0.18,
    haloLit: 0.34,
  );

  static const cartridge = LauncherButtonTheme(
    launchFill: LinearGradient(
      begin: _fillFrom,
      end: _fillTo,
      colors: [Color(0xFFFF4A17), Color(0xFFFF4A17), Color(0xFFFF4A17)],
      stops: _fillStops,
    ),
    downloadFill: LinearGradient(
      begin: _fillFrom,
      end: _fillTo,
      colors: [Color(0xFF0090A8), Color(0xFF0090A8), Color(0xFF0090A8)],
      stops: _fillStops,
    ),
    downloadDepth: Color(0xFF00596A),
    core: RadialGradient(
      center: _coreCenter,
      radius: _coreRadius,
      colors: [Color(0x00FFFFFF), Color(0x00FFFFFF), Color(0x00FFFFFF)],
      stops: _coreStops,
    ),
    haloRest: 0,
    haloLit: 0,
  );

  static LauncherButtonTheme of(BuildContext context) =>
      Theme.of(context).extension<LauncherButtonTheme>() ?? arclight;

  /// Заливка клавиши этого тона.
  LinearGradient fillOf(LauncherTone tone) => switch (tone) {
    LauncherTone.launch => launchFill,
    LauncherTone.download => downloadFill,
  };

  /// Торец клавиши этого тона.
  Color depthOf(LauncherTone tone, EvaporatePalette colors) => switch (tone) {
    LauncherTone.launch => colors.depth,
    LauncherTone.download => downloadDepth,
  };

  /// Цвет ореола: тот же, что середина заливки, — клавиша светит своим
  /// цветом, а не общим.
  Color haloOf(LauncherTone tone, EvaporatePalette colors) => switch (tone) {
    LauncherTone.launch => colors.primaryFill,
    LauncherTone.download => colors.accentFill,
  };

  /// Все поля по порядку — для проверки, что `lerp` и `copyWith` не
  /// забыли ни одного.
  List<Object> get values => [
    launchFill,
    downloadFill,
    downloadDepth,
    core,
    haloRest,
    haloLit,
  ];

  @override
  LauncherButtonTheme copyWith({double? haloLit}) => LauncherButtonTheme(
    launchFill: launchFill,
    downloadFill: downloadFill,
    downloadDepth: downloadDepth,
    core: core,
    haloRest: haloRest,
    haloLit: haloLit ?? this.haloLit,
  );

  @override
  LauncherButtonTheme lerp(
    ThemeExtension<LauncherButtonTheme>? other,
    double t,
  ) {
    if (other is! LauncherButtonTheme) return this;
    return LauncherButtonTheme(
      launchFill: LinearGradient.lerp(launchFill, other.launchFill, t)!,
      downloadFill: LinearGradient.lerp(downloadFill, other.downloadFill, t)!,
      downloadDepth: Color.lerp(downloadDepth, other.downloadDepth, t)!,
      core: RadialGradient.lerp(core, other.core, t)!,
      haloRest: lerpDouble(haloRest, other.haloRest, t)!,
      haloLit: lerpDouble(haloLit, other.haloLit, t)!,
    );
  }
}
