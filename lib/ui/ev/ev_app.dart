import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import 'data/real_library.dart';
import 'data/sample_data.dart';
import 'data/sample_downloads.dart';
import 'data/sample_friend_profiles.dart';
import 'data/sample_friends.dart';
import 'data/sample_profile.dart';
import 'data/sample_saves.dart';
import 'data/sample_session.dart';
import 'design/appearance.dart';
import 'design/effects.dart';
import 'design/theme.dart';
import 'design/tokens.dart';
import 'downloads/download_data.dart';
import 'first_run/ev_add_torrent.dart';
import 'first_run/ev_first_run_widgets.dart';
import 'first_run/first_run_controller.dart';
import 'first_run/first_run_data.dart';
import 'first_run/scenario.dart';
import 'friends/friends_data.dart';
import 'launch/ev_launch_ritual.dart';
import 'library/hero_state.dart';
import 'modes/ev_pult.dart';
import 'modes/ev_view_switch.dart';
import 'modes/modes_data.dart';
import 'overlay/ev_overlay.dart';
import 'profile/profile_data.dart';
import 'returning/ev_return_widgets.dart';
import 'returning/return_data.dart';
import 'saves/saves_data.dart';
import 'screens/downloads_page.dart';
import 'screens/friend_profile_page.dart';
import 'screens/friends_page.dart';
import 'screens/library_page.dart';
import 'screens/profile_page.dart';
import 'screens/saves_page.dart';
import 'screens/settings_page.dart';
import 'screens/term_page.dart';
import 'screens/wall_page.dart';
import 'settings/settings_data.dart';
import 'sheet/ev_game_sheet.dart';
import 'shell/ev_palette.dart';
import 'shell/ev_section.dart';
import 'shell/ev_shell.dart';
import 'sound/cues.dart';
import 'sound/ev_sound.dart';
import 'sound/soloud_out.dart';
import 'sound/voices.dart';
import 'util/units.dart';
import 'widgets/ev_game_card.dart';
import 'widgets/ev_icon.dart';
import 'widgets/ev_surfaces.dart';

/// Прототип целиком; прежде это был `main` прототипа.
void runEvaporateDesign() => runApp(const EvaporateApp());

class EvaporateApp extends StatefulWidget {
  const EvaporateApp({
    super.key,
    this.effects,
    this.sound,
    this.readCatalog = true,
  });

  /// Показывать чтение каталога первые 300 мс. Тесты, которым скелет
  /// не нужен, его выключают.
  final bool readCatalog;

  /// Эффекты атмосферы. Не задано — приложение заводит свои, всё включено.
  /// Тесты передают [EvEffects.still], чтобы кадры не шли бесконечно.
  final EvEffects? effects;

  /// Звук. Не задан — приложение заводит свой на SoLoud; выключен он
  /// в любом случае, пока его не включат в настройках.
  final EvSound? sound;

  @override
  State<EvaporateApp> createState() => _EvaporateAppState();
}

class _EvaporateAppState extends State<EvaporateApp> {
  final _appearance = EvAppearance();
  // Движка нет, а состояния продукта есть: их переключает «Разработка»
  // в настройках — как панель состояний в прототипе.
  final _state = ValueNotifier<EvHeroState>(EvHeroState.ready);
  final _downloads = ValueNotifier<EvDownloadsState>(EvDownloadsState.active);
  final _saves = ValueNotifier<EvSavesState>(EvSavesState.synced);
  final _friendsState = ValueNotifier<EvFriendsState>(EvFriendsState.normal);
  // Тумблеры приватности — настройка, а не состояние раздела: уход
  // на другой экран их не сбрасывает.
  final _shares = ValueNotifier<Set<EvShare>>(EvShare.values.toSet());
  // Вид библиотеки — выбор окна: уход в другой раздел его не сбрасывает.
  final _view = ValueNotifier<EvLibraryView>(EvLibraryView.showcase);
  final _settings = EvSettings();
  late final _ownEffects = widget.effects == null ? EvEffects() : null;
  final _shell = EvShellController();
  late final _ownSound = widget.sound == null
      ? EvSound(out: EvSoLoudOut())
      : null;
  EvSound get _sound => widget.sound ?? _ownSound!;

  /// Звук знает, в фокусе ли окно: отдушина дышит только в активном.
  late final _lifecycle = AppLifecycleListener(
    onStateChange: (s) => _sound.focused = s == AppLifecycleState.resumed,
  );
  late EvSection _section;

  /// Смена раздела звучит: низ уходит вверх.
  void _onSection() {
    if (_shell.section == _section) return;
    _section = _shell.section;
    _sound.play(EvVoice.swish);
  }

  @override
  void initState() {
    super.initState();
    _section = _shell.section;
    _shell.addListener(_onSection);
    _lifecycle;
  }

  final _navigator = GlobalKey<NavigatorState>();
  late final _firstRun = EvFirstRunController(
    onStep: _enterStep,
    onExit: _leaveFlow,
    read: widget.readCatalog,
  );
  Route<double>? _addRoute;

  /// «Пока вас не было»: только во втором запуске — открыт или свёрнут
  /// в плашку. Состояние окна, как и сам второй запуск.
  final _digest = ValueNotifier<EvDigestState>(EvDigestState.open);
  late final _return = EvReturnController(
    onStep: _enterReturn,
    onExit: () => _setHero(EvHeroState.ready),
  );

  /// Идущий сценарий — его листают полоса и стрелки.
  EvScenario? get _scenario => _firstRun.run != null
      ? _firstRun
      : _return.index != null
      ? _return
      : null;

  /// Шаги «Возвращения»: новости → загрузки из дайджеста → дайджест
  /// свернулся → продолжили с той же секунды.
  void _enterReturn(int step) {
    if (_firstRun.run != null) _firstRun.exit();
    _setHero(EvHeroState.returned);
    _digest.value = step == 0 ? EvDigestState.open : EvDigestState.folded;
    _shell.go(step == 1 ? EvSection.downloads : EvSection.library);
    if (step != 3) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _navigator.currentContext;
      if (context == null) return;
      showEvLaunchRitual(
        context,
        title: sampleHero.title,
        stages: sampleLaunchStages,
      );
    });
  }

  /// Вход на шаг первого запуска: куда смотреть и что открыть.
  void _enterStep(EvFirstRunStep step) {
    if (_return.index != null) _return.exit();
    _shell.go(step.downloads ? EvSection.downloads : EvSection.library);
    final open = _addRoute;
    if (step != EvFirstRunStep.magnet && open != null && open.isActive) {
      // Шаг пролистали стрелкой — диалог уходит вместе с ним.
      _navigator.currentState?.removeRoute(open);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _navigator.currentContext;
      if (context == null) return;
      if (step == EvFirstRunStep.magnet) _askMagnet();
      if (step == EvFirstRunStep.launch) {
        showEvLaunchRitual(
          context,
          title: EvFirstRun.game.title,
          stages: sampleLaunchStages,
        );
      }
    });
  }

  /// Из сценария — в обычную библиотеку; открытый диалог закрывается.
  void _leaveFlow() {
    final open = _addRoute;
    if (open != null && open.isActive) {
      _navigator.currentState?.removeRoute(open);
    }
    _shell.go(EvSection.library);
  }

  /// Диалог «Добавить раздачу». «Скачать» ведёт в очередь, отказ —
  /// обратно к пустой библиотеке.
  Future<void> _askMagnet() async {
    final navigator = _navigator.currentState;
    if (navigator == null || _addRoute != null) return;
    final drive = sampleDrives.first;
    final route = evAddTorrentRoute(
      game: EvFirstRun.game,
      freeGb: drive.freeGb,
      folder: '${drive.path}\\AshenVerge',
    );
    _addRoute = route;
    final gb = await navigator.push(route);
    _addRoute = null;
    if (_firstRun.run?.step != EvFirstRunStep.magnet) return;
    gb == null
        ? _firstRun.go(EvFirstRunStep.installed)
        : _firstRun.download(gb);
  }

  /// Клавиши сценария: `←` `→` листают. Из пустой библиотеки `Ctrl+V`
  /// и `Ctrl+O` ведут к добавлению раздачи.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final run = _firstRun.run;
    final scenario = _scenario;
    if (scenario != null && key == LogicalKeyboardKey.arrowRight) {
      scenario.next();
      return KeyEventResult.handled;
    }
    if (scenario != null && key == LogicalKeyboardKey.arrowLeft) {
      scenario.previous();
      return KeyEventResult.handled;
    }
    final paste =
        HardwareKeyboard.instance.isControlPressed &&
        (key == LogicalKeyboardKey.keyV || key == LogicalKeyboardKey.keyO);
    final empty = run?.step.empty ?? _firstRun.catalog == EvCatalog.empty;
    if (paste && empty && _shell.section == EvSection.library) {
      _firstRun.go(EvFirstRunStep.magnet);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  EvEffects get _effects => widget.effects ?? _ownEffects!;

  /// Состояние игры и состояние очереди — разные вещи, но «нет сети» —
  /// свойство окна, и его видят оба. Поэтому офлайн ходит парой: включить
  /// его с одной стороны — значит включить с обеих.
  /// Событие движка звучит, когда состояние сменилось, а не когда то же
  /// выбрали ещё раз.
  void _cue<T>(T before, T after, EvVoice? Function(T) voiceOf) {
    if (before == after) return;
    final voice = voiceOf(after);
    if (voice != null) _sound.play(voice);
  }

  void _setHero(EvHeroState next) {
    _cue(_state.value, next, evHeroCue);
    // Второй запуск открывается новостями.
    if (next == EvHeroState.returned && _state.value != next) {
      _digest.value = EvDigestState.open;
    }
    _state.value = next;
    if (next == EvHeroState.offline) {
      _downloads.value = EvDownloadsState.offline;
    } else if (_downloads.value == EvDownloadsState.offline) {
      _downloads.value = EvDownloadsState.active;
    }
  }

  void _setDownloads(EvDownloadsState next) {
    // «Нет сети» с этой стороны звучит один раз: пару меняют без голоса.
    _cue(_downloads.value, next, evDownloadsCue);
    _downloads.value = next;
    if (next == EvDownloadsState.offline) {
      _state.value = EvHeroState.offline;
    } else if (_state.value == EvHeroState.offline) {
      _state.value = EvHeroState.ready;
    }
  }

  void _setSaves(EvSavesState next) {
    _cue(_saves.value, next, evSavesCue);
    _saves.value = next;
  }

  @override
  void dispose() {
    _return.dispose();
    _digest.dispose();
    _firstRun.dispose();
    _settings.dispose();
    _shares.dispose();
    _view.dispose();
    _friendsState.dispose();
    _saves.dispose();
    _downloads.dispose();
    _state.dispose();
    _appearance.dispose();
    _ownEffects?.dispose();
    _lifecycle.dispose();
    _ownSound?.dispose();
    _shell.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EvAppearanceScope(
      appearance: _appearance,
      child: EvEffectsScope(
        effects: _effects,
        child: EvSoundScope(
          sound: _sound,
          child: ListenableBuilder(
            listenable: _appearance,
            builder: (context, _) => MaterialApp(
              title: 'Evaporate',
              debugShowCheckedModeBanner: false,
              // Тема одна — тёмная, по требованию продукта.
              theme: _appearance.theme,
              themeAnimationDuration: EvMotion.screen,
              themeAnimationCurve: EvMotion.easeOut,
              navigatorKey: _navigator,
              // Обложки приложения внутри карточек подписывают себя его
              // переводами: без них L.of(context) падает.
              localizationsDelegates: L.localizationsDelegates,
              supportedLocales: L.supportedLocales,
              locale: const Locale('ru'),
              // Полоса сценария — над всеми маршрутами, и над диалогом тоже:
              // `z-index` у неё в прототипе выше, чем у диалога.
              builder: (context, child) => Focus(
                onKeyEvent: _onKey,
                child: ListenableBuilder(
                  listenable: Listenable.merge([_firstRun, _return]),
                  builder: (context, _) =>
                      _FlowLayer(scenario: _scenario, child: child!),
                ),
              ),
              home: ListenableBuilder(
                listenable: Listenable.merge([
                  _state,
                  _downloads,
                  _saves,
                  _friendsState,
                  _shares,
                  _view,
                  _settings,
                  _firstRun,
                  _digest,
                ]),
                builder: (context, _) => _Home(
                  shell: _shell,
                  state: _state.value,
                  onState: _setHero,
                  downloads: _downloads.value,
                  onDownloads: _setDownloads,
                  saves: _saves.value,
                  onSaves: _setSaves,
                  friendsState: _friendsState.value,
                  onFriends: (next) => _friendsState.value = next,
                  settings: _settings,
                  firstRun: _firstRun,
                  digest: _digest.value,
                  onDigest: (next) => _digest.value = next,
                  onReturn: () => _return.go(0),
                  view: _view.value,
                  onView: (next) => _view.value = next,
                  shares: _shares.value,
                  onShare: (share, on) => _shares.value = on
                      ? {..._shares.value, share}
                      : ({..._shares.value}..remove(share)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home({
    required this.shell,
    required this.state,
    required this.onState,
    required this.downloads,
    required this.onDownloads,
    required this.saves,
    required this.onSaves,
    required this.friendsState,
    required this.onFriends,
    required this.settings,
    required this.firstRun,
    required this.digest,
    required this.onDigest,
    required this.onReturn,
    required this.view,
    required this.onView,
    required this.shares,
    required this.onShare,
  });

  final EvShellController shell;

  /// Состояние игры в герое — одно на окно: его читают герой, плашки
  /// в верхней полосе и полоса действий в карточке игры.
  final EvHeroState state;

  final ValueChanged<EvHeroState> onState;

  /// Состояние очереди раздач — одно на окно: его видят раздел
  /// «Загрузки» и плашки в верхней полосе.
  final EvDownloadsState downloads;

  final ValueChanged<EvDownloadsState> onDownloads;

  /// Состояние облака сохранений — третье состояние окна.
  final EvSavesState saves;

  final ValueChanged<EvSavesState> onSaves;

  /// Состояние раздела «Друзья». «Нет сети» сюда не входит: это
  /// состояние окна, и раздел читает его из состояния героя.
  final EvFriendsState friendsState;

  final ValueChanged<EvFriendsState> onFriends;

  /// Всё, что выбрано в «Настройках».
  final EvSettings settings;

  /// Первый запуск и каталог — состояние окна.
  final EvFirstRunController firstRun;

  /// «Пока вас не было» — открыт, свёрнут в плашку или его нет.
  final EvDigestState digest;

  final ValueChanged<EvDigestState> onDigest;

  /// Пройти «Возвращение» с начала.
  final VoidCallback onReturn;

  /// Как показана библиотека: витрина, стена или терминал.
  final EvLibraryView view;

  final ValueChanged<EvLibraryView> onView;

  /// Что видят друзья — тумблеры в профиле.
  final Set<EvShare> shares;

  final void Function(EvShare share, bool on) onShare;

  /// Запуск игры — ритуал поверх всего окна; когда он уходит, герой
  /// становится «Игра запущена», как в прототипе. Только у героя: сессия
  /// в данных одна — его.
  Future<void> _launch(BuildContext context, SampleGame game) async {
    await showEvLaunchRitual(
      context,
      title: game.title,
      stages: sampleLaunchStages,
    );
    if (game.title == sampleHero.title) onState(EvHeroState.running);
  }

  /// Главная кнопка у игры вне героя: игра на диске — ритуал, нет —
  /// загрузки, где она уже качается или ждёт.
  void _play(BuildContext context, SampleGame game) =>
      game.state == EvGameState.ready
      ? _launch(context, game)
      : shell.go(EvSection.downloads);

  /// «Пульт» — весь экран для геймпада; входит, как смена раздела.
  void _pult(BuildContext context, EvDownloads queue) {
    EvSoundScope.maybeOf(context)?.play(EvVoice.swish);
    showEvPult(
      context,
      games: sampleLibraryFor(state),
      rate: formatRate(queue.downKb, digits: 1),
      initials: sampleUserInitials,
      onPlay: (g) => _play(context, g),
      onDetails: (g) => _open(context, g),
    );
  }

  /// Карточка игры. Запуск из неё — тот же ритуал, а полоса действий
  /// в ней читает состояние окна — как `cardState` в прототипе.
  void _open(BuildContext context, SampleGame game) => showEvGameSheet(
    context,
    game: game,
    // Во втором запуске у героя другая версия — это та же игра.
    state: game.title == sampleHero.title ? state : null,
    onLaunch: () => _launch(context, game),
    onInstall: () => onState(EvHeroState.installing),
    onQuit: () => onState(EvHeroState.ready),
    onOverlay: () => _overlay(context, running: true),
  );

  /// Очередь раздач. Пока идёт игра, приём и отдача ужаты до предела
  /// из настроек — и верхняя полоса, и раздачи говорят про одни байты.
  EvDownloads _queue({required bool running}) {
    final queue = sampleDownloadsFor(downloads).withSlots(settings.slots);
    if (!running) return queue;
    return queue.capped(
      downKb: EvSettings.inGameDownloadMb * 1000,
      upKb: EvSettings.inGameUploadMb * 1000,
    );
  }

  /// Оверлей поверх идущей игры. Друзья — те же, что в правой колонке;
  /// фоном — та раздача, что принимает.
  void _overlay(BuildContext context, {required bool running}) {
    final queue = _queue(running: running);
    final friends = sampleFriendsFor(friendsState, offline: false);
    showEvOverlay(
      context,
      session: sampleSession,
      friends: friends.people
          .where((p) => p.status != EvPersonStatus.offline)
          .take(4)
          .toList(),
      online: friends.online,
      background: queue.torrents.where((t) => t.active).firstOrNull,
      onQuit: () => onState(EvHeroState.ready),
    );
  }

  /// Единственное действие события дайджеста. Уводит на другой экран —
  /// дайджест сворачивается; открывает карточку — остаётся.
  void _digestAction(BuildContext context, EvDigestEvent e) {
    switch (e.target) {
      case EvDigestTarget.downloads:
        onDigest(EvDigestState.folded);
        shell.go(EvSection.downloads);
      case EvDigestTarget.friend:
        onDigest(EvDigestState.folded);
        final anton = samplePeople.first;
        shell.open(EvSection.friends, anton, crumb: anton.name);
      case EvDigestTarget.heroCard || EvDigestTarget.gameCard:
        _open(context, e.game!);
      case null:
        break;
    }
  }

  /// Очередь первого запуска: одна раздача первой игры в фазе шага,
  /// до неё и после — пусто.
  EvDownloads _firstQueue(EvFirstRun run) {
    final t = run.torrent;
    return EvDownloads(
      torrents: [?t],
      queue: const [],
      slots: settings.slots,
      peakKb: t?.peakKb ?? 0,
      toDiskShare: .92,
    );
  }

  /// Плашки верхней полосы читают оба состояния окна. Левая — всегда
  /// приём, и он складывается из раздач, а не пишется отдельным числом.
  /// В первом запуске правая — что с движком на этом шаге.
  List<EvPill> _pills(EvDownloads queue) {
    // Свёрнутый дайджест живёт плашкой: по ней он возвращается.
    if (state == EvHeroState.returned && digest == EvDigestState.folded) {
      return [
        EvPill(
          formatRate(queue.downKb, digits: 1),
          status: queue.downKb == 0 ? EvStatus.idle : EvStatus.busy,
        ),
        EvPill(
          'Пока вас не было · ${sampleDigestEvents().length}',
          status: EvStatus.news,
          onTap: () => onDigest(EvDigestState.open),
        ),
      ];
    }
    if (_engine case final engine? when state != EvHeroState.offline) {
      return [
        EvPill(
          formatRate(queue.downKb, digits: 1),
          status: queue.downKb == 0 ? EvStatus.idle : EvStatus.busy,
        ),
        EvPill(engine.$1, status: engine.$2),
      ];
    }
    return _statePills(queue);
  }

  /// Что с движком на шаге первого запуска или пока читается каталог;
  /// `null` — плашку пишет состояние окна.
  ///
  /// Отдельным геттером, а не `?.` с `??` в одном выражении: такую запись
  /// веб-компилятор собирал без проверки на `null`, и окно в браузере
  /// падало на первом кадре.
  (String, EvStatus)? get _engine {
    final step = firstRun.run?.engine;
    if (step != null) return step;
    if (firstRun.catalog == EvCatalog.reading) {
      return ('Читаем каталог', EvStatus.busy);
    }
    return null;
  }

  List<EvPill> _statePills(EvDownloads queue) => switch (state) {
    EvHeroState.offline => const [
      EvPill('Нет сети', status: EvStatus.idle),
      EvPill('Движок на паузе', status: EvStatus.idle),
    ],
    // Пока игра идёт, приём ограничен, чтобы не отнимать у неё сеть:
    // очередь уже ужата, плашка складывает её раздачи, как всегда.
    EvHeroState.running => [
      EvPill(formatRate(queue.downKb, digits: 1), status: EvStatus.busy),
      const EvPill('Игра запущена'),
    ],
    _ => [
      EvPill(
        formatRate(queue.downKb, digits: 1),
        status: queue.downKb == 0 ? EvStatus.idle : EvStatus.busy,
      ),
      // Сохранения просят внимания громче очереди: потерять точку
      // отката хуже, чем медленно качать.
      if (saves == EvSavesState.conflict)
        const EvPill('1 конфликт', status: EvStatus.warn)
      else if (saves == EvSavesState.noCloud)
        const EvPill('Облако недоступно', status: EvStatus.idle)
      else if (saves == EvSavesState.uploading)
        const EvPill('Выгрузка 3 из 5', status: EvStatus.busy)
      else
        switch (downloads) {
          EvDownloadsState.noSeeds => const EvPill(
            'Нет раздающих',
            status: EvStatus.warn,
          ),
          EvDownloadsState.noSpace => const EvPill(
            'Диск переполнен',
            status: EvStatus.bad,
          ),
          EvDownloadsState.hash => const EvPill(
            'Перепроверка',
            status: EvStatus.busy,
          ),
          EvDownloadsState.empty => const EvPill(
            'Движок простаивает',
            status: EvStatus.idle,
          ),
          _ => const EvPill('Движок готов'),
        },
    ],
  };

  @override
  Widget build(BuildContext context) {
    final appearance = EvAppearanceScope.of(context);
    // Предел одновременных загрузок — из настроек: лишние раздачи ждут
    // в очереди, и друзья по ним не раздают.
    final run = firstRun.run;
    final queue = run == null
        ? _queue(running: state == EvHeroState.running)
        : _firstQueue(run);
    final offline = state == EvHeroState.offline;
    final friends = sampleFriendsFor(
      friendsState,
      offline: offline,
      queue: queue,
    );
    return EvShell(
      controller: shell,
      // В первом запуске библиотека — шаг сценария, её вид не меняют.
      libraryTools: run == null
          ? EvViewSwitch(
              view: view,
              onView: onView,
              onPult: () => _pult(context, queue),
            )
          : null,
      keys: {PhysicalKeyboardKey.keyP: () => _pult(context, queue)},
      initials: sampleUserInitials,
      userName: sampleUserName,
      friendsOnline: friends.online,
      downloadsActive: queue.torrents.length,
      status: _pills(queue),
      commands: [
        for (final g in evLibrary)
          EvCommand(
            title: g.title,
            subtitle: g.subtitle,
            cover: (g.palette, g.seed),
            hint: L.of(context).evPaletteOpen,
            onRun: () => _open(context, g),
            // Запускать можно только то, что уже на диске; остальное ведёт
            // туда, где оно качается, — как «Стена» и «Пульт» в прототипе.
            onLaunch: () => _play(context, g),
          ),
        for (final s in EvSection.values)
          EvCommand(
            title: s.labelOf(L.of(context)),
            subtitle: L.of(context).evPaletteSection(s.hotkey),
            icon: s.icon,
            hint: L.of(context).evPaletteOpen,
            onRun: () => shell.go(s),
          ),
        for (final s in EvSkin.values)
          EvCommand(
            title: 'Сменить тему на ${s.label}',
            subtitle: 'команда · ${s.hint}',
            icon: EvIcons.settings,
            onRun: () => appearance.skin = s,
          ),
        for (final g in EvGeometry.values)
          EvCommand(
            title: 'Радиус скругления · ${g.label}',
            subtitle: 'команда · потолок радиуса',
            icon: EvIcons.settings,
            onRun: () => appearance.geometry = g,
          ),
      ],
      pageBuilder: (context, section) => switch (section) {
        EvSection.library when run == null && view == EvLibraryView.wall =>
          WallPage(
            games: evRealLibrary?.games ?? sampleLibraryFor(state),
            selected: (evRealLibrary?.games ?? sampleLibraryFor(state)).first,
            onPlay: (g) => _play(context, g),
            onOpen: (g) => _open(context, g),
          ),
        EvSection.library when run == null && view == EvLibraryView.term =>
          TermPage(
            games: evRealLibrary?.games ?? sampleLibraryFor(state),
            onPlay: (g) => _play(context, g),
          ),
        EvSection.library => LibraryPage(
          // В первом запуске библиотека, герой и его состояние — шага.
          state: switch (run?.step) {
            null => state,
            EvFirstRunStep.installing => EvHeroState.installing,
            _ => EvHeroState.ready,
          },
          catalog: run == null
              ? firstRun.catalog
              : run.step.empty
              ? EvCatalog.empty
              : EvCatalog.normal,
          heroContent:
              run != null && run.step.index >= EvFirstRunStep.firstGame.index
              ? run.hero
              : run == null && state == EvHeroState.ready
              ? evRealLibrary?.heroContent
              : null,
          onAdd: () => firstRun.go(EvFirstRunStep.magnet),
          digest: state == EvHeroState.returned && run == null
              ? EvDigestSlot(
                  open: digest == EvDigestState.open,
                  events: sampleDigestEvents(),
                  onDone: () => onDigest(EvDigestState.folded),
                  onAction: (e) => _digestAction(context, e),
                )
              : null,
          onOtherSave: () => shell.go(EvSection.saves),
          onInstall: () => onState(EvHeroState.installing),
          onQuit: () => onState(EvHeroState.ready),
          onOverlay: () => _overlay(context, running: true),
          games: run?.library ?? evLibrary,
          hero: run?.library.firstOrNull ?? evHero,
          sessions: run == null ? evSessions : const [],
          // Правая колонка библиотеки показывает тех же друзей, что
          // и раздел, — и так же гаснет без сети.
          friends: friends.people.take(4).toList(),
          friendsOnline: friends.online,
          downloads: queue,
          onLaunch: (g) => _launch(context, g),
          onOpen: (g) => _open(context, g),
        ),
        EvSection.downloads => DownloadsPage(downloads: queue),
        // Страница друга — внутри раздела: рейл остаётся на «Друзьях»,
        // в хлебной крошке имя, Esc и «Все друзья» ведут обратно.
        EvSection.friends when shell.detail is EvPerson => FriendProfilePage(
          profile: sampleFriendProfile(shell.detail! as EvPerson),
          library: sampleLibrary,
          yourGame: sampleHero,
          offline: offline,
          onBack: shell.back,
          onJoin: (g) => g.state == EvGameState.ready
              ? _launch(context, g)
              : shell.go(EvSection.downloads),
          onAbout: (g) => _open(context, g),
          onOwnPrivacy: () => shell.go(EvSection.profile),
        ),
        EvSection.friends => FriendsPage(
          friends: friends,
          onPerson: (p) => shell.open(EvSection.friends, p, crumb: p.name),
          rateKb: queue.downKb,
          onInvite: () => onFriends(EvFriendsState.normal),
          onDownloads: () => shell.go(EvSection.downloads),
        ),
        EvSection.saves => SavesPage(
          saves: sampleSavesFor(saves),
          onResolve: () => onSaves(EvSavesState.synced),
          onRetry: () => onSaves(EvSavesState.synced),
        ),
        EvSection.settings => SettingsPage(
          settings: settings,
          drives: sampleDrives,
          ratio: formatRatio(sampleProfile.ratio),
          cloud: (sampleSavesFor(saves).usedGb, sampleSavesFor(saves).quotaGb),
          state: state,
          onState: onState,
          downloads: downloads,
          onDownloads: onDownloads,
          saves: saves,
          onSaves: onSaves,
          friendsState: friendsState,
          onFriends: onFriends,
          catalog: firstRun.catalog,
          onCatalog: (c) => firstRun.catalog = c,
          onFirstRun: () => firstRun.go(EvFirstRunStep.installed),
          onReturn: onReturn,
          view: view,
          onView: (v) {
            onView(v);
            shell.go(EvSection.library);
          },
          onPult: () => _pult(context, queue),
          onOverlay: () {
            onState(EvHeroState.running);
            _overlay(context, running: true);
          },
          onFriendPage: (p) => shell.open(EvSection.friends, p, crumb: p.name),
        ),
        EvSection.profile => ProfilePage(
          profile: sampleProfile,
          shares: shares,
          onShare: onShare,
        ),
      },
    );
  }
}

/// Слой над маршрутами: окно и, пока идёт сценарий, его полоса внизу.
class _FlowLayer extends StatelessWidget {
  const _FlowLayer({required this.scenario, required this.child});

  final EvScenario? scenario;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final run = scenario;
    final index = run?.index;
    if (run == null || index == null) return child;
    final width = MediaQuery.sizeOf(context).width;
    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 16,
          child: Center(
            child: SizedBox(
              width: (width - 24).clamp(0, EvFlowBar.width),
              // Над навигатором нет Material: без него у текста не было
              // бы стиля, и Flutter подчеркнул бы его жёлтым.
              child: Material(
                type: MaterialType.transparency,
                child: EvFlowBar(
                  index: index,
                  count: run.count,
                  title: run.title,
                  detail: run.detail,
                  onPrevious: run.previous,
                  onNext: run.next,
                  onExit: run.exit,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
