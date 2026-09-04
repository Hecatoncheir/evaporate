import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../models/download_task.dart';
import '../../models/game.dart';
import '../theme.dart';
import '../widgets/nav_tile.dart';
import 'foil_card.dart';
import '../../l10n/app_localizations.dart';

/// Плитка библиотеки: вертикальная обложка 2:3, как в Steam.
///
/// Обложка тут не украшение, а единственная подпись: сетку читают по
/// картинкам, а не по названиям. Поэтому название показывается только там,
/// где картинки нет, — и во всю плитку, чтобы игру всё равно было видно.
class GameCoverTile extends StatelessWidget {
  const GameCoverTile({
    super.key,
    required this.game,
    required this.selected,
    required this.onOpen,
    required this.onFocused,
    this.focusNode,
  });

  final Game game;

  /// Игра, к которой возвращаются, закрыв её страницу.
  final bool selected;
  final VoidCallback onOpen;
  final VoidCallback onFocused;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final task = context.select<DownloadsBloc, DownloadTask?>(
      (bloc) => bloc.state.taskForGame(game),
    );
    final running = task != null && task.state != DownloadState.complete;

    return NavTile(
      focusNode: focusNode,
      onTap: onOpen,
      // Фокус восстанавливается на той игре, с которой ушли на её страницу:
      // иначе после «назад» сетка теряла бы место, и искать пришлось бы
      // заново.
      autofocus: selected,
      onFocusChange: (has) {
        if (has) onFocused();
      },
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      borderRadius: 10,
      borderWidth: 2.5,
      focusedScale: 1.06,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7.5),
          boxShadow: [
            BoxShadow(
              // Тень своя, а не из темы: она отделяет обложку от фона, и в
              // светлой теме нужна не меньше, чем в тёмной.
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7.5),
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                FoilSurface(
                  child: _Art(game: game, underStrip: running),
                ),
                if (running) _ProgressStrip(task: task),
                if (!running) _StatusBadge(game: game),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Обложка читается только с диска: открытие библиотеки не обращается к Steam.
class _Art extends StatelessWidget {
  const _Art({required this.game, required this.underStrip});

  final Game game;

  /// Снизу лежит полоса загрузки — название должно её обойти.
  final bool underStrip;

  @override
  Widget build(BuildContext context) {
    final path = game.coverPath;

    Widget image(String path, {required Widget Function() onError}) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => onError(),
        // Проявление вместо рывка: обложки приходят вразнобой, и сетка
        // иначе моргает пятнами по мере их прихода.
        frameBuilder: (context, child, frame, wasCached) => AnimatedOpacity(
          opacity: frame == null && !wasCached ? 0 : 1,
          duration: const Duration(milliseconds: 220),
          child: child,
        ),
      );
    }

    final fallback = _TitlePlate(game: game, underStrip: underStrip);
    if (path == null) return fallback;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Подложка лежит под картинкой всегда: пока обложка грузится, плитка
        // не должна быть пустой дырой.
        fallback,
        image(path, onError: () => const SizedBox.shrink()),
      ],
    );
  }
}

/// Название на подложке — когда обложки нет.
///
/// Цвет выводится из названия, а не берётся из палитры: соседние плитки
/// должны отличаться друг от друга, иначе библиотека без картинок выглядит
/// стеной одинаковых прямоугольников. Оттенок у игры всегда один и тот же.
///
/// Тёмная в обеих темах, как и настоящие обложки: подложка заменяет
/// картинку, а не продолжает фон приложения, и белое название по ней должно
/// читаться при любых настройках.
class _TitlePlate extends StatelessWidget {
  const _TitlePlate({required this.game, required this.underStrip});

  final Game game;
  final bool underStrip;

  @override
  Widget build(BuildContext context) {
    final hue = (game.title.hashCode % 360).abs().toDouble();
    final top = HSLColor.fromAHSL(1, hue, 0.32, 0.27).toColor();
    final bottom = HSLColor.fromAHSL(1, (hue + 24) % 360, 0.30, 0.13).toColor();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, bottom],
        ),
      ),
      padding: EdgeInsets.fromLTRB(12, 12, 12, underStrip ? 52 : 12),
      alignment: Alignment.bottomLeft,
      child: Text(
        game.title,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          // Подложка своя и в обеих темах тёмная — белый по ней читается,
          // а цвет из палитры на ней бы терялся.
          color: Colors.white,
          fontSize: 15,
          height: 1.2,
          fontWeight: FontWeight.w700,
          shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
        ),
      ),
    );
  }
}

/// Значок в углу: установлена, запущена, не заладилось.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (game.status) {
      GameStatus.running => (Icons.play_arrow_rounded, context.colors.accent),
      GameStatus.installed => (Icons.check_rounded, context.colors.accent),
      GameStatus.error => (Icons.priority_high_rounded, context.colors.danger),
      _ => (null, Colors.transparent),
    };
    if (icon == null) return const SizedBox.shrink();

    // Сверху, а не снизу: снизу у плитки без обложки стоит название, и
    // значок налезал бы на него.
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            // Кружок лежит на обложке, а не на фоне приложения: подложка
            // тёмная в обеих темах, иначе значок пропадал бы на светлых
            // картинках.
            color: Colors.black.withValues(alpha: 0.66),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}

/// Полоса загрузки поверх нижнего края обложки.
class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final indeterminate = task.isMetadata || task.totalBytes == 0;
    final label = switch (task) {
      _ when task.isQueued => L.of(context).inQueue,
      _ when task.isMetadata => L.of(context).metadataShort,
      _ when task.state == DownloadState.paused => L.of(context).pausedShort,
      _ when indeterminate => '…',
      _ => '${(task.progress * 100).toStringAsFixed(0)}%',
    };

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        color: Colors.black.withValues(alpha: 0.66),
        padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: indeterminate ? null : task.progress,
                minHeight: 3,
                backgroundColor: Colors.white24,
                color: context.colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
