import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/downloads/downloads_bloc.dart';
import '../../../bloc/navigation/navigation_bloc.dart';
import '../../../bloc/settings/settings_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/app_settings.dart';
import '../../../models/download_task.dart';
import '../../../models/game.dart';
import '../../../models/library_effect.dart';
import '../../../services/metadata/release_name.dart';
import '../../labels.dart';
import '../../library/library_grid_controller.dart';
import '../art/key_art.dart';
import '../widgets/ev_effect_cover.dart';
import '../widgets/ev_game_card.dart';

/// Карточка горизонтальной полки: вид прототипа, выбор и фокус приложения.
class EvLibraryCard extends StatelessWidget {
  const EvLibraryCard({
    super.key,
    required this.game,
    required this.controller,
    required this.width,
  });

  final Game game;
  final LibraryGridController controller;
  final double width;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final selected = context.select<NavigationBloc, bool>(
      (bloc) => bloc.state.selectedGameId == game.id,
    );
    final effects = context.select<SettingsBloc, Appearance>(
      (bloc) => bloc.state.appearance,
    );
    final task = context.select<DownloadsBloc, DownloadTask?>(
      (bloc) => bloc.state.taskForGame(game),
    );
    final title = ReleaseName.clean(game.title);
    final label = gameStatusLabel(l, game.status);
    final progress = task != null && !task.isFinished ? task.progress : null;
    final seed = game.id.codeUnits.fold(
      0,
      (value, code) => ((value * 31) + code) & 0x7fffffff,
    );
    final nav = context.read<NavigationBloc>();
    void open() => nav.add(GameOpened(game.id));
    return ListenableBuilder(
      listenable: Listenable.merge([controller, controller.focusNode(game.id)]),
      builder: (context, child) {
        final active =
            (controller.hoveredId ?? nav.state.selectedGameId) == game.id;
        return Semantics(
          button: true,
          selected: selected,
          focusable: true,
          focused: controller.focusNode(game.id).hasFocus,
          onFocus: () => controller.requestFocus(game.id),
          label: [
            title.isEmpty ? game.title : title,
            label,
            if (progress != null) percentLabel(l, progress),
          ].join(', '),
          excludeSemantics: true,
          onTap: open,
          child: EvGameCard(
            title: title.isEmpty ? game.title : title,
            subtitle: [
              label,
              if (game.sizeBytes > 0) bytesLabel(l, game.sizeBytes),
            ].join(' · '),
            palette: EvCoverPalette.ash,
            seed: seed,
            width: width,
            state: game.isInstalled
                ? EvGameState.ready
                : game.status == GameStatus.downloading
                ? EvGameState.downloading
                : EvGameState.queued,
            progress: progress,
            badge: game.isInstalled ? null : label,
            focusNode: controller.focusNode(game.id),
            autofocus: selected,
            showFocusRing: effects.isOn(LibraryEffect.selectionFrame),
            onTap: open,
            onActiveChanged: (value) {
              controller.hover(game.id, hovered: value);
              if (value) nav.add(GameSelected(game.id));
            },
            onFocusChange: (value) {
              if (!value) return;
              nav.add(GameSelected(game.id));
              // Оба окна прокрутки доводят карточку до видимого: полка
              // по горизонтали, страница — под полосами каркаса.
              final box = context.findRenderObject();
              if (box is RenderBox) {
                box.showOnScreen(rect: (Offset.zero & box.size).inflate(8));
              }
            },
            cover: (context, lifted) => KeyedSubtree(
              key: controller.tileKey(game.id),
              child: EvEffectCover(
                game: game,
                active: active,
                palette: EvCoverPalette.ash,
                seed: seed,
                effects: effects,
              ),
            ),
          ),
        );
      },
    );
  }
}
