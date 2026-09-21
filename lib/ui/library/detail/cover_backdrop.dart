import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../models/game.dart';
import '../../theme.dart';

/// Обложка игры приглушённым фоном её страницы.
///
/// Страница игры до сих пор начиналась с корпуса: одинакового у всех и ни
/// о чём не говорящего. Обложка на фоне отвечает на «чья это страница»
/// раньше, чем человек дочитает название.
///
/// Фон, а не картинка: он размыт, затемнён и тает к середине экрана —
/// ниже начинается содержимое, и спорить с ним ему нечем. Отсюда и три
/// слоя, каждый из которых нужен:
///
/// * размытие — чтобы под текстом не читались детали, которые глаз будет
///   пытаться разобрать;
/// * затемнение — чтобы белый текст на светлой обложке остался белым
///   текстом, а не пропал;
/// * растворение к низу — чтобы у фона был конец, а не обрезанный край.
///
/// Берётся тот же файл, что уже показан на самой странице: его расшифровку
/// Flutter держит в кэше, и второй показ не стоит ничего. Это, кстати, и
/// причина, по которой окружение (`AmbientLight`) считает свой цвет от
/// названия, а не от пикселей: там картинку пришлось бы разбирать на
/// каждую перелистку, здесь она и так уже разобрана.
class CoverBackdrop extends StatelessWidget {
  const CoverBackdrop({super.key, required this.game, this.enabled = true});

  final Game game;
  final bool enabled;

  /// Докуда фон доживает: доля высоты, на которой он сходит на нет.
  static const fadeAt = 0.55;

  @override
  Widget build(BuildContext context) {
    final path = game.details.coverPath;
    if (!enabled || path == null || path.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = context.colors;
    return IgnorePointer(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          // Держится вверху, тает к середине и ниже неё уже ничего.
          colors: [AppColors.opaque, AppColors.opaque, AppColors.transparent],
          stops: [0, 0.32, fadeAt],
        ).createShader(bounds),
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(path),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                // Пропала обложка — просто нет фона. Ронять из-за
                // украшения страницу игры незачем.
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
              // Затемнение поверх: у светлой обложки иначе не остаётся
              // разницы между фоном и текстом на нём.
              ColoredBox(
                color: colors.background.withValues(
                  alpha: HardwareSurfaceTheme.of(context).scrimOpacity,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
