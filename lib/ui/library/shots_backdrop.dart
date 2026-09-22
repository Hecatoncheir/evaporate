import 'package:flutter/material.dart';

import '../widgets/decorative_motion.dart';
import 'featured/shots_slideshow.dart';

/// Кадры из игры подложкой под крупной обложкой библиотеки.
///
/// Обложка отвечает на «какая это игра», кадр — на «какая это игра на
/// самом деле»: полка из вертикальных плашек показывает рисованные обложки,
/// а не то, во что человек собирается играть. Кадры Steam отдаёт в том же
/// `appdetails`, из которого приходят описание и оценка, — их и берём.
///
/// Показываются по кругу с перекрёстным затуханием и медленно ползут: это
/// та же мысль, что у `AmbientLight`, — цвет и движение в оболочку приносят
/// сами игры, а не корпус.
///
/// Ползёт медленно и по чуть-чуть намеренно. Приложением управляют и с
/// геймпада, где человек держит направление и ждёт мгновенной реакции;
/// быстрый фон там читается как подтормаживание, а не как жизнь.
///
/// Без кадров виджет ничего не рисует и возвращает [fallback] — обложку.
/// Так и должно быть у половины библиотеки: у торрент-релиза, не сошедшегося
/// со Steam, кадров нет и взяться им неоткуда.
class ShotsBackdrop extends StatelessWidget {
  const ShotsBackdrop({
    super.key,
    required this.shots,
    required this.enabled,
    required this.fallback,
  });

  /// Пути к сохранённым кадрам. Пусто — обычное дело.
  final List<String> shots;
  final bool enabled;

  /// Чем показывать игру, если кадров нет или их не прочесть.
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    if (!enabled || shots.isEmpty) return fallback;

    return DecorativeMotion(
      enabled: true,
      builder: (context, clock, _) =>
          ShotsSlideshow(shots: shots, clock: clock, fallback: fallback),
    );
  }
}
