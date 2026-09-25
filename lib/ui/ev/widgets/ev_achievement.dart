import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../design/theme.dart';
import 'ev_icon.dart';

/// Плитка достижения: кубок и две строки. Одна и та же в карточке игры
/// и в профиле — полученное выглядит одинаково, где бы его ни показали.
class EvAchievementTile extends StatelessWidget {
  const EvAchievementTile({
    super.key,
    required this.name,
    required this.detail,
    required this.unlocked,
  });

  final String name;

  /// Условие в карточке игры, «игра · когда» в профиле.
  final String detail;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: ev.radii.b2,
        color: c.ink.withValues(alpha: .022),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EvTrophyIcon(unlocked: unlocked, size: 32),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: ev.text.ui(
                    ev.text.body,
                    weight: FontWeight.w500,
                    size: 13,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: ev.text.body.copyWith(fontSize: 11.5, color: c.ink4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Кубок в квадрате. Полученный светится янтарём, остальные — контур.
class EvTrophyIcon extends StatelessWidget {
  const EvTrophyIcon({super.key, required this.unlocked, required this.size});

  final bool unlocked;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: ev.radii.b4,
        border: Border.all(
          color: unlocked ? c.hot1.withValues(alpha: .45) : c.line,
        ),
        color: unlocked ? c.hot1.withValues(alpha: .1) : null,
        boxShadow: unlocked
            ? [BoxShadow(color: c.hot1.withValues(alpha: .25), blurRadius: 20)]
            : null,
      ),
      child: Center(
        child: EvIcon(
          EvIcons.trophy,
          size: 15,
          color: unlocked ? c.hot2 : c.ink4,
        ),
      ),
    );
  }
}

/// Сетка достижений: колонки от 190 px, шов 6 px — `.achgrid`. Плитки
/// одного ряда одной высоты, как в сетке CSS.
///
/// Число колонок можно передать готовым: тогда сетка не спрашивает свою
/// ширину и её можно положить в панель, которая равняется по соседке
/// через `IntrinsicHeight`, — `LayoutBuilder` там не работает.
class EvAchievementGrid extends StatelessWidget {
  const EvAchievementGrid({super.key, required this.children, this.columns});

  final List<Widget> children;
  final int? columns;

  static const minWidth = 190.0;
  static const gap = 6.0;

  /// Сколько колонок помещается в [width].
  static int columnsFor(double width) =>
      math.max(1, (width + gap) ~/ (minWidth + gap));

  @override
  Widget build(BuildContext context) {
    if (columns != null) return _rows(columns!);
    return LayoutBuilder(
      builder: (context, box) => _rows(columnsFor(box.maxWidth)),
    );
  }

  Widget _rows(int columns) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var row = 0; row * columns < children.length; row++) ...[
        if (row > 0) const SizedBox(height: gap),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var col = 0; col < columns; col++) ...[
                if (col > 0) const SizedBox(width: gap),
                Expanded(
                  child: row * columns + col < children.length
                      ? children[row * columns + col]
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      ],
    ],
  );
}
