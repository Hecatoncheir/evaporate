import 'dart:io';

import 'package:flutter/material.dart';

import '../../../models/game.dart';
import '../../theme.dart';
import 'cover_title_plate.dart';

/// Обложка читается только с диска: открытие библиотеки не обращается к Steam.
class CoverArt extends StatelessWidget {
  const CoverArt({super.key, required this.game, required this.underStrip});

  final Game game;

  /// Снизу лежит полоса загрузки — название должно её обойти.
  final bool underStrip;

  @override
  Widget build(BuildContext context) {
    final path = game.coverPath;

    final fallback = CoverTitlePlate(game: game, underStrip: underStrip);
    if (path == null) return fallback;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Подложка лежит под картинкой всегда: пока обложка грузится, плитка
        // не должна быть пустой дырой.
        fallback,
        Image.file(
          File(path),
          fit: BoxFit.cover,
          // Не прочиталась — остаётся подложка под ней: пустая дыра на
          // месте плитки хуже, чем плитка без картинки.
          errorBuilder: (context, error, stack) => const SizedBox.shrink(),
          // Проявление вместо рывка: обложки приходят вразнобой, и сетка
          // иначе моргает пятнами по мере их прихода.
          frameBuilder: (context, child, frame, wasCached) => AnimatedOpacity(
            opacity: frame == null && !wasCached ? 0 : 1,
            duration: context.motion.fast,
            child: child,
          ),
        ),
      ],
    );
  }
}
