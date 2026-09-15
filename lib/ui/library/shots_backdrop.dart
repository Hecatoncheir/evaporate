import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets/decorative_motion.dart';

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

  /// Сколько кадр держится на экране и сколько длится перетекание.
  static const hold = 9.0;
  static const fade = 1.6;

  /// Насколько кадр отъезжает за свой черёд, долей ширины.
  static const drift = 0.06;

  /// Доля черёда, на которую следующий кадр трогается раньше своего срока.
  ///
  /// Равна перетеканию, и это не совпадение: приходящий кадр виден ровно
  /// столько, сколько длится перетекание, и, стой он на месте, к мгновению,
  /// когда предыдущий убирают, он простоял бы неподвижно всё это время — а
  /// потом дёрнулся с места. Трогаясь заранее, он к смене уже идёт.
  static const preroll = fade / (hold + fade);

  /// Весь путь кадра в долях черёда: собственный черёд плюс разбег.
  static const span = 1 + preroll;

  @override
  Widget build(BuildContext context) {
    if (!enabled || shots.isEmpty) return fallback;

    return DecorativeMotion(
      enabled: true,
      builder: (context, clock, _) =>
          _Slideshow(shots: shots, clock: clock, fallback: fallback),
    );
  }
}

class _Slideshow extends StatelessWidget {
  const _Slideshow({
    required this.shots,
    required this.clock,
    required this.fallback,
  });

  final List<String> shots;
  final ValueListenable<double> clock;
  final Widget fallback;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ValueListenableBuilder<double>(
      valueListenable: clock,
      builder: (context, time, _) {
        const period = ShotsBackdrop.hold + ShotsBackdrop.fade;
        final turn = time / period;
        final index = turn.floor();
        final phase = turn - index;

        // Перетекание занимает хвост черёда, поэтому следующий кадр нужен
        // только под конец: остальное время он не рисуется вовсе.
        final blend = phase <= ShotsBackdrop.hold / period
            ? 0.0
            : Curves.easeInOut.transform(
                (phase - ShotsBackdrop.hold / period) /
                    (ShotsBackdrop.fade / period),
              );

        return Stack(
          fit: StackFit.expand,
          children: [
            _Shot(
              path: shots[index % shots.length],
              // Кадр отъезжает за свой черёд целиком, а не за одно
              // перетекание: иначе движение шло бы рывками — стоял,
              // дёрнулся, стоял.
              offset: phase,
              opacity: 1,
              fallback: fallback,
            ),
            if (blend > 0)
              _Shot(
                path: shots[(index + 1) % shots.length],
                // Отрицательное смещение — тот самый разбег: к началу
                // своего черёда кадр придёт ровно к нулю и продолжит путь
                // без стыка.
                offset: phase - 1,
                opacity: blend,
                fallback: fallback,
              ),
          ],
        );
      },
    ),
  );
}

/// Один кадр: сдвинут по горизонтали и увеличен ровно настолько, чтобы
/// сдвиг не открыл край.
class _Shot extends StatelessWidget {
  const _Shot({
    required this.path,
    required this.offset,
    required this.opacity,
    required this.fallback,
  });

  final String path;

  /// Доля черёда, пройденная кадром: 0 — начало своего черёда, 1 — уход.
  /// Отрицательное значение — разбег до собственного черёда.
  final double offset;
  final double opacity;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    // Середина пути, а не половина черёда: путь начинается с разбега, и
    // отсчёт от 0.5 увёл бы кадр в одну сторону сильнее, чем в другую.
    const middle = (1 - ShotsBackdrop.preroll) / 2;
    final shift = (offset - middle) * ShotsBackdrop.drift;

    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        // Масштаб под весь размах сдвига и ещё десятая часть сверху: без
        // запаса край кадра приходится ровно на границу, и округление в
        // крайних положениях обнажает у рамки полоску фона.
        scale: 1 + ShotsBackdrop.drift * ShotsBackdrop.span * 1.1,
        // Доля собственной ширины, а не ширины окна: подложка занимает
        // крупный кадр библиотеки, а не экран, и от `MediaQuery` дрейф
        // менялся бы с размером окна при неизменном кадре.
        child: FractionalTranslation(
          translation: Offset(shift, 0),
          child: Image.file(
            File(path),
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
            // Кадр лежит миниатюрой 600×338, но подложка бывает шире:
            // просим декодировать под ширину окна, а не под свой размер.
            cacheWidth: 1024,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => fallback,
          ),
        ),
      ),
    );
  }
}
