import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/navigation/navigation_bloc.dart';
import '../../../bloc/settings/settings_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/game.dart';
import '../../../models/shelf.dart';
import '../../../services/metadata/release_name.dart';
import '../../labels.dart';
import '../../library/library_grid_controller.dart';
import '../art/ev_art.dart';
import '../art/key_art.dart';
import '../library/ev_session_row.dart';
import '../library/library_layout.dart';
import '../widgets/ev_surfaces.dart';
import 'ev_library_card.dart';

/// Полки прототипа на найденных играх: установленные, остальные и недавние.
class EvLibraryShelves extends StatelessWidget {
  const EvLibraryShelves({
    super.key,
    required this.games,
    required this.controller,
  });

  final List<Game> games;
  final LibraryGridController controller;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final layout = EvLibraryLayout.of(MediaQuery.sizeOf(context));
    final recent = gamesOnShelf(games, Shelf.recent).take(6).toList();
    final installed = gamesOnShelf(games, Shelf.installed);
    final incoming = gamesOnShelf(games, Shelf.notInstalled);
    controller.shelfIds = [for (final game in games) game.id];
    final indices = {for (final (i, game) in games.indexed) game.id: i};
    return Padding(
      padding: EdgeInsets.fromLTRB(layout.gutter, 0, layout.gutter, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (layout.showSessions && recent.isNotEmpty)
            _Section(
              key: const ValueKey('recent-section'),
              title: l.tabRecent,
              count: recent.length,
              layout: layout,
              child: EvSessionGrid(
                minWidth: layout.sessionMinWidth,
                children: [for (final game in recent) _RecentGame(game: game)],
              ),
            ),
          if (installed.isNotEmpty)
            _Section(
              key: const ValueKey('installed-section'),
              title: l.tabInstalled,
              count: installed.length,
              layout: layout,
              child: _Shelf(
                key: const ValueKey('installed-shelf'),
                games: installed,
                controller: controller,
                layout: layout,
                indices: indices,
              ),
            ),
          if (incoming.isNotEmpty)
            _Section(
              key: const ValueKey('incoming-section'),
              title: l.tabNotInstalled,
              count: incoming.length,
              layout: layout,
              child: _Shelf(
                key: const ValueKey('incoming-shelf'),
                games: incoming,
                controller: controller,
                layout: layout,
                indices: indices,
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    super.key,
    required this.title,
    required this.count,
    required this.layout,
    required this.child,
  });
  final String title;
  final int count;
  final EvLibraryLayout layout;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: layout.sectionTop),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EvSectionHeader(title, count: '$count'),
        SizedBox(height: layout.sectionHeadGap),
        child,
      ],
    ),
  );
}

/// Геометрия полки взята из прототипа: активная обложка рисуется последней.
class _Shelf extends StatelessWidget {
  const _Shelf({
    super.key,
    required this.games,
    required this.controller,
    required this.layout,
    required this.indices,
  });
  final List<Game> games;
  final LibraryGridController controller;
  final EvLibraryLayout layout;
  final Map<String, int> indices;

  @override
  Widget build(BuildContext context) {
    final scale = context.select<SettingsBloc, double>(
      (bloc) => bloc.state.appearance.libraryScale,
    );
    final width = layout.cardWidth * scale;
    final selectedId = context.select<NavigationBloc, String?>(
      (bloc) => bloc.state.selectedGameId,
    );
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final active = games.indexWhere(
          (game) => game.id == (controller.hoveredId ?? selectedId),
        );
        final order = [
          for (var i = 0; i < games.length; i++)
            if (i != active) i,
          if (active >= 0) active,
        ];
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: EdgeInsets.only(top: 8, bottom: layout.shelfBottom - 2),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final i in order)
                Padding(
                  key: ValueKey(games[i].id),
                  padding: EdgeInsets.only(left: i * (width + 16)),
                  child: IndexedSemantics(
                    index: indices[games[i].id]!,
                    child: EvLibraryCard(
                      game: games[i],
                      controller: controller,
                      width: width,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Недавняя игра открывает свою страницу; число часов и дата — из модели.
class _RecentGame extends StatelessWidget {
  const _RecentGame({required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final title = ReleaseName.clean(game.title);
    const fallback = EvCover(palette: EvCoverPalette.ash, seed: 0);
    return EvSessionRow(
      key: ValueKey(game.id),
      title: title.isEmpty ? game.title : title,
      subtitle:
          '${formatDurationLabel(l, game.play.playtime)} · ${dateTimeLabel(l, game.play.lastPlayed!)}',
      palette: EvCoverPalette.ash,
      seed: 0,
      cover: SizedBox(
        width: 46,
        height: 60,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: game.details.coverPath == null
              ? fallback
              : Image.file(
                  File(game.details.coverPath!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => fallback,
                ),
        ),
      ),
      onTap: () => context.read<NavigationBloc>().add(GameOpened(game.id)),
    );
  }
}
