import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/downloads/downloads_bloc.dart';
import '../../models/download_task.dart';
import '../../models/game.dart';
import 'detail/game_detail_body.dart';

/// Карточка игры целиком.
///
/// Страница занимает всё окно, а строка длиной в тысячу точек не читается —
/// колонка держится в разумной ширине и стоит по центру.
class GameDetail extends StatelessWidget {
  const GameDetail({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    final task = context.select<DownloadsBloc, DownloadTask?>(
      (bloc) => bloc.state.taskForGame(game),
    );
    // Истории скоростей здесь больше не заводятся: она одна на приложение
    // (`DownloadHistoryBloc`), и график с показаниями берут её по задаче.
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 940),
        child: GameDetailBody(game: game, task: task),
      ),
    );
  }
}
