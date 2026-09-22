import 'package:flutter/material.dart';

// Цвета украшений и игр — яркие, декоративные, и текстом ими не пишут.
// Лежат отдельно от палитры корпуса: та выверена по контрасту и меняется
// со схемой, а эти — оттенки на стекле и в свете.

/// Насыщенные цвета — декоративные. Текст ими не красят: для него есть
/// цвета темы, выверенные по контрасту в `theme_test.dart`.
///
/// Набор собран вокруг ночной схемы: золото, сигнальный голубой и коралл —
/// те же три голоса, что и у корпуса, только в полную силу.
const libraryInkColors = [
  Color(0xFFF2C368),
  Color(0xFF49B7E0),
  Color(0xFFE0574A),
  Color(0xFFF2A93B),
  Color(0xFF9A7BD8),
  Color(0xFFF2C368),
];

/// Цвета, не зависящие от темы: оформление обложек, эффекты и рамка окна.
/// Здесь лежат базовые значения; прозрачность виджеты всё ещё анимируют.
abstract final class AppColors {
  static const transparent = Colors.transparent;

  /// Непрозрачное для масок: в `BlendMode.dstIn` важна одна альфа, а не
  /// цвет, — но писать `Colors.white` там, где речь о непрозрачности,
  /// значит заставлять читателя гадать, при чём тут белый.
  static const opaque = Colors.white;
  static const coverText = Colors.white;
  static const coverTextShadow = Colors.black54;
  static final coverShadow = Colors.black.withValues(alpha: 0.3);
  static final coverOverlay = Colors.black.withValues(alpha: 0.66);
  static final detailOverlay = Colors.black.withValues(alpha: 0.62);
  static const coverProgressTrack = Colors.white24;
  static const foilHighlight = Colors.white;
  static const waveHighlight = Colors.white;

  // Затемнение поверх обложки героя: три ступени одного чернильного цвета,
  // чтобы надпись читалась на любой картинке, а верх кадра остался виден.
  static const heroShadeStrong = Color(0xED06080B);
  static const heroShadeMiddle = Color(0x7006080B);
  static const heroShadeClear = Color(0x0806080B);
  static const heroEyebrow = Color(0xFFE9C877);
  static const heroBody = Color(0xFFB9C0C8);
  static const heroPanel = Color(0xC90D1116);

  /// Полоса света, проходящая по герою. Единственное, что двигается по
  /// обложке само: она и отличает живой кадр от вклеенной картинки.
  static final artSweep = Colors.white.withValues(alpha: 0.09);

  // Портал горит своим огнём, а не цветом темы: он один и тот же на светлой
  // и на тёмной подложке — как искры и должны выглядеть.
  static const portalSpark = Color(0xFFFFE79A);
  static const portalRim = Color(0xFFFF8A1F);
}

/// Запасные цвета обложки, выведенные из названия игры.
///
/// Устойчивы и не зависят от темы: игра без обложки должна выглядеть
/// одинаково от запуска к запуску, иначе библиотека каждый раз чужая.
List<Color> gameCoverColors(String title) {
  final hue = _titleHue(title);
  return [
    HSLColor.fromAHSL(1, hue, 0.34, 0.30).toColor(),
    HSLColor.fromAHSL(1, (hue + 24) % 360, 0.32, 0.13).toColor(),
  ];
}

/// Оттенки, которыми игра может подсветить корпус.
///
/// Набор выверенный, а не весь круг: свободный оттенок от хеша названия
/// рано или поздно выдаёт болотно-зелёный или грязно-жёлтый, и оболочка
/// выглядит не «своей у каждого», а сломанной. Шесть якорей — киноварь,
/// янтарь, изумруд, лазурь, индиго и фуксия — все живут рядом с золотом
/// корпуса и ни один не спорит с ним.
const ambientHues = [8.0, 36.0, 152.0, 202.0, 258.0, 322.0];

/// Свет, которым игра заливает корпус, пока она выбрана.
///
/// Взят от названия, а не от пикселей обложки: разбор картинки означал бы
/// её декодирование на каждую перелистку, а разница на глаз невелика —
/// свет всё равно размыт до пятна. Зато цвет не меняется от запуска к
/// запуску: игра всегда светит одним и тем же.
List<Color> gameAmbientColors(String title) {
  final hash = title.hashCode.abs();
  // Небольшой разброс внутри якоря: две игры одного семейства оттенков
  // всё-таки светят по-разному.
  final hue =
      (ambientHues[hash % ambientHues.length] + (hash ~/ 7) % 13 - 6 + 360) %
      360;
  return [
    HSLColor.fromAHSL(1, hue, 0.70, 0.50).toColor(),
    HSLColor.fromAHSL(1, (hue + 28) % 360, 0.64, 0.42).toColor(),
    HSLColor.fromAHSL(1, (hue + 320) % 360, 0.56, 0.24).toColor(),
  ];
}

double _titleHue(String title) => (title.hashCode % 360).abs().toDouble();
