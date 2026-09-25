import 'package:flutter/widgets.dart';

import '../data/sample_data.dart';
import '../downloads/download_data.dart';
import '../first_run/ev_first_run_widgets.dart';
import '../first_run/first_run_data.dart';
import '../friends/friends_data.dart';
import '../library/ev_hero.dart';
import '../library/ev_session_row.dart';
import '../library/ev_side_cards.dart';
import '../library/hero_state.dart';
import '../library/library_layout.dart';
import '../returning/ev_return_widgets.dart';
import '../util/plural.dart';
import '../util/units.dart';
import '../widgets/ev_effect_cover.dart';
import '../widgets/ev_game_card.dart';
import '../widgets/ev_surfaces.dart';

/// Библиотека — направление A, «Витрина»: герой с игрой, на которой вы
/// остановились, «Продолжить», полка установленного и то, что качается.
///
/// Раскладка идёт ступенями прототипа ([EvLibraryLayout]): на окне до 800
/// по высоте герой ужимается до 300 px, а «Продолжить» складывается; от
/// 1800 по ширине справа встаёт колонка с друзьями и загрузками.
class LibraryPage extends StatelessWidget {
  const LibraryPage({
    super.key,
    required this.games,
    required this.hero,
    required this.sessions,
    required this.friends,
    required this.friendsOnline,
    required this.downloads,
    this.state = EvHeroState.ready,
    this.catalog = EvCatalog.normal,
    this.heroContent,
    this.onAdd,
    this.digest,
    this.onOtherSave,
    this.onLaunch,
    this.onOpen,
    this.onInstall,
    this.onQuit,
    this.onOverlay,
  });

  final List<SampleGame> games;

  /// Игра в герое.
  final SampleGame hero;

  /// Недавние сессии, без игры в герое.
  final List<SampleGame> sessions;

  final List<EvPerson> friends;
  final int friendsOnline;

  /// Очередь раздач — та же, что у верхней полосы: пока идёт игра, она
  /// ужата, и правая колонка пишет те же скорости.
  final EvDownloads downloads;

  /// Состояние игры в герое: установлена, качается, идёт, офлайн.
  final EvHeroState state;

  /// Что с каталогом: пуст — вместо героя приглашение, читается —
  /// скелет. Пустой список игр — тоже пустой каталог.
  final EvCatalog catalog;

  /// Герой не из шести состояний, а свой: первая игра в первом запуске.
  final EvHeroContent? heroContent;

  /// Добавить игру: оба пути из пустой библиотеки и зона перетаскивания.
  final VoidCallback? onAdd;

  /// «Пока вас не было» — во втором запуске. На широком окне стоит первым
  /// в правой колонке, на остальных висит справа под верхней полосой.
  final Widget? digest;

  /// «Другое» у точки сохранения в герое.
  final VoidCallback? onOtherSave;

  /// Удержание «Играть» в герое дошло до конца.
  final ValueChanged<SampleGame>? onLaunch;

  /// «Установить» и «Обновить и играть».
  final VoidCallback? onInstall;

  /// «Завершить» — игра закончилась.
  final VoidCallback? onQuit;

  /// «Оверлей» поверх идущей игры.
  final VoidCallback? onOverlay;

  /// Открыть карточку игры: «Подробнее», строка «Продолжить», обложка.
  final ValueChanged<SampleGame>? onOpen;

  @override
  Widget build(BuildContext context) {
    final layout = EvLibraryLayout.of(MediaQuery.sizeOf(context));
    if (catalog == EvCatalog.reading) {
      return _Bare(
        layout: layout,
        child: EvLibrarySkeleton(layout: layout),
      );
    }
    if (catalog == EvCatalog.empty || games.isEmpty) {
      return _Bare(
        layout: layout,
        child: EvLibraryEmpty(onScan: onAdd, onMagnet: onAdd, onDrop: onAdd),
      );
    }
    final installed = [
      for (final g in games)
        if (g.state == EvGameState.ready) g,
    ];
    final incoming = [
      for (final g in games)
        if (g.state != EvGameState.ready) g,
    ];

    Widget section(String title, String count, Widget child) => Padding(
      padding: EdgeInsets.only(top: layout.sectionTop),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EvSectionHeader(title, count: count),
          SizedBox(height: layout.sectionHeadGap),
          child,
        ],
      ),
    );

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: layout.gutter),
        EvHero(
          layout: layout,
          palette: hero.palette,
          seed: hero.seed,
          title: hero.title,
          state: state,
          content: heroContent ?? sampleHeroStates[state]!,
          onLaunch: onLaunch == null ? null : () => onLaunch!(hero),
          onDetails: onOpen == null ? null : () => onOpen!(hero),
          onInstall: onInstall,
          onQuit: onQuit,
          onOverlay: onOverlay,
          onOtherSave: onOtherSave,
        ),
        if (layout.showSessions && sessions.isNotEmpty)
          section(
            'Продолжить',
            '${sessions.length} '
                '${ruPlural(sessions.length, 'сессия', 'сессии', 'сессий')}',
            EvSessionGrid(
              minWidth: layout.sessionMinWidth,
              children: [
                for (final g in sessions)
                  EvSessionRow(
                    title: g.title,
                    subtitle: '${formatPlayed(g.played)} · ${g.lastPlayed}',
                    palette: g.palette,
                    seed: g.seed,
                    onTap: onOpen == null ? null : () => onOpen!(g),
                  ),
              ],
            ),
          ),
        section(
          'Библиотека',
          '${installed.length} '
              '${ruPlural(installed.length, 'установлена', 'установлено', 'установлено')}',
          _Shelf(games: installed, layout: layout, onOpen: onOpen),
        ),
        if (incoming.isNotEmpty)
          section(
            'Скоро на диске',
            'качается',
            _Shelf(games: incoming, layout: layout, onOpen: onOpen),
          ),
      ],
    );

    // Экран лежит под полосами каркаса, поэтому сверху и снизу отступает
    // на них: содержимое уходит под стекло только при прокрутке.
    final chrome = MediaQuery.paddingOf(context);
    final list = ListView(
      primary: true,
      padding: EdgeInsets.fromLTRB(
        layout.gutter,
        chrome.top,
        layout.gutter,
        26 + chrome.bottom,
      ),
      children: [
        if (layout.sideWidth == 0)
          main
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: main),
              SizedBox(width: layout.gutter),
              SizedBox(
                width: layout.sideWidth,
                child: Padding(
                  padding: EdgeInsets.only(top: layout.gutter),
                  child: _SideColumn(
                    digest: digest,
                    friends: friends,
                    friendsOnline: friendsOnline,
                    downloads: downloads,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
    final float = digest;
    if (float == null || layout.sideWidth > 0) return list;
    // Узкое окно: дайджест висит справа под верхней полосой, поверх полок.
    return Stack(
      children: [
        list,
        Positioned(
          right: layout.gutter,
          top: chrome.top + 12,
          width: EvDigest.width,
          child: float,
        ),
      ],
    );
  }
}

/// Библиотека без героя и полок: пустая или ещё читается.
class _Bare extends StatelessWidget {
  const _Bare({required this.layout, required this.child});

  final EvLibraryLayout layout;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final chrome = MediaQuery.paddingOf(context);
    return ListView(
      primary: true,
      padding: EdgeInsets.fromLTRB(
        layout.gutter,
        chrome.top,
        layout.gutter,
        26 + chrome.bottom,
      ),
      children: [child],
    );
  }
}

/// Полка: ряд обложек с горизонтальной прокруткой. Сверху запас на подъём
/// карточки при наведении, иначе её кромку срезало бы.
class _Shelf extends StatefulWidget {
  const _Shelf({required this.games, required this.layout, this.onOpen});

  final List<SampleGame> games;
  final EvLibraryLayout layout;
  final ValueChanged<SampleGame>? onOpen;

  @override
  State<_Shelf> createState() => _ShelfState();
}

/// Карточки лежат слоями на своих местах, а не рядом в строке: горящая
/// рисуется последней, поверх соседей. Иначе соседняя, нарисованная позже,
/// закрывала бы искры по её кромке.
class _ShelfState extends State<_Shelf> {
  static const _gap = 16.0;

  /// Какая карточка горит — под курсором или в фокусе.
  int? _active;

  void _activeChanged(int index, bool active) {
    if (active) {
      setState(() => _active = index);
    } else if (_active == index) {
      setState(() => _active = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final games = widget.games;
    final layout = widget.layout;
    final active = _active != null && _active! < games.length ? _active : null;
    final order = [
      for (var i = 0; i < games.length; i++)
        if (i != active) i,
      ?active,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // Искры выходят за кромку карточки: полка их не обрезает.
      clipBehavior: Clip.none,
      // 8 + 16 — те же 24 px, что 6 + 18 в прототипе, но подъём на 8 px
      // помещается целиком
      padding: EdgeInsets.only(top: 8, bottom: layout.shelfBottom - 2),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final i in order)
            Padding(
              key: ValueKey(games[i].game?.id ?? '${games[i].title}#$i'),
              padding: EdgeInsets.only(left: i * (layout.cardWidth + _gap)),
              child: _ShelfCard(
                game: games[i],
                width: layout.cardWidth,
                onOpen: widget.onOpen,
                onActiveChanged: (value) => _activeChanged(i, value),
              ),
            ),
        ],
      ),
    );
  }
}

/// Одна карточка полки: у настоящей игры обложка приложения с его
/// украшениями, у примера — рисованная обложка прототипа.
class _ShelfCard extends StatelessWidget {
  const _ShelfCard({
    required this.game,
    required this.width,
    required this.onActiveChanged,
    this.onOpen,
  });

  final SampleGame game;
  final double width;
  final ValueChanged<SampleGame>? onOpen;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) {
    final g = game;
    return EvGameCard(
      title: g.title,
      subtitle: g.subtitle,
      palette: g.palette,
      seed: g.seed,
      state: g.state,
      progress: g.progress,
      badge: g.badge,
      width: width,
      onTap: onOpen == null ? null : () => onOpen!(g),
      onActiveChanged: onActiveChanged,
      cover: switch (g.game) {
        final real? => (context, active) => EvEffectCover(
          game: real,
          active: active,
          palette: g.palette,
          seed: g.seed,
        ),
        null => null,
      },
    );
  }
}

/// Правая колонка широкого окна: то, что на узком живёт всплывающими
/// панелями, — друзья и загрузки.
class _SideColumn extends StatelessWidget {
  const _SideColumn({
    this.digest,
    required this.friends,
    required this.friendsOnline,
    required this.downloads,
  });

  final Widget? digest;
  final List<EvPerson> friends;
  final int friendsOnline;
  final EvDownloads downloads;

  @override
  Widget build(BuildContext context) {
    // Качается то, что принимает: без сети и на паузе строк нет.
    final active = [
      for (final t in downloads.torrents)
        if (t.active && t.downKb != null) t,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (digest != null) ...[digest!, const SizedBox(height: 14)],
        EvFriendsCard(friends: friends, online: friendsOnline),
        if (active.isNotEmpty) ...[
          const SizedBox(height: 14),
          EvDownloadsNowCard(
            downloads: [
              for (final t in active)
                EvDownloadLine(
                  title: t.game.title,
                  detail: '${percent(t.progress)} % · ${formatRate(t.downKb!)}',
                  progress: t.progress,
                  palette: t.game.palette,
                  seed: t.game.seed,
                  checking: t.bar == EvBarTone.cool,
                ),
            ],
            rate: formatRate(downloads.downKb),
            slots: downloads.slots,
          ),
        ],
      ],
    );
  }
}
