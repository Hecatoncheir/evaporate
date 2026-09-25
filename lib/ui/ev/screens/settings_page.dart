import 'package:flutter/material.dart';

import '../data/sample_data.dart';
import '../data/sample_friends.dart';
import '../design/appearance.dart';
import '../design/effects.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../downloads/download_data.dart';
import '../first_run/first_run_data.dart';
import '../friends/friends_data.dart';
import '../gallery/gallery_page.dart';
import '../library/hero_state.dart';
import '../modes/modes_data.dart';
import '../saves/saves_data.dart';
import '../settings/ev_settings_widgets.dart';
import '../settings/settings_catalog.dart';
import '../settings/settings_data.dart';
import '../settings/settings_search.dart';
import '../sound/ev_sound.dart';
import '../widgets/ev_controls.dart';
import '../widgets/ev_focusable.dart';
import '../widgets/ev_icon.dart';
import '../widgets/ev_surfaces.dart';

/// Настройки: липкая колонка слева, поиск и десять разделов, которые
/// можно назвать вслух. Раньше это была плоская сетка панелей, которая
/// росла пристройками.
///
/// Последним стоит «Разработка»: движка нет, и состояния продукта
/// переключаются здесь, как панелью «Состояния» в прототипе. Уйдёт
/// вместе с появлением движка.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.settings,
    required this.drives,
    required this.ratio,
    required this.cloud,
    required this.state,
    required this.onState,
    required this.downloads,
    required this.onDownloads,
    required this.saves,
    required this.onSaves,
    required this.friendsState,
    required this.onFriends,
    this.hour,
    this.onFriendPage,
    this.catalog = EvCatalog.normal,
    this.onCatalog,
    this.onFirstRun,
    this.onReturn,
    this.onOverlay,
    this.view,
    this.onView,
    this.onPult,
  });

  final EvSettings settings;

  /// Папки с играми — из библиотеки.
  final List<EvDrive> drives;

  /// Рейтинг раздачи из профиля: «2,41».
  final String ratio;

  /// Облако сохранений: занято и всего, ГБ, — из раздела «Сохранения».
  final (double, double) cloud;

  /// Который час. `null` — по часам компьютера.
  final int? hour;

  /// Состояние игры в герое. Движка нет, поэтому его переключают здесь.
  final EvHeroState state;

  final ValueChanged<EvHeroState> onState;

  /// Состояние очереди раздач — по тем же причинам и рядом.
  final EvDownloadsState downloads;

  final ValueChanged<EvDownloadsState> onDownloads;

  /// Состояние облака сохранений — по тем же причинам и рядом.
  final EvSavesState saves;

  final ValueChanged<EvSavesState> onSaves;

  /// Состояние раздела «Друзья» — по тем же причинам и рядом.
  final EvFriendsState friendsState;

  final ValueChanged<EvFriendsState> onFriends;

  /// Открыть страницу друга — два состояния прототипа: открытый профиль
  /// и закрытый.
  final ValueChanged<EvPerson>? onFriendPage;

  /// Что с каталогом игр: обычный, пустой, читается.
  final EvCatalog catalog;

  final ValueChanged<EvCatalog>? onCatalog;

  /// Пройти первый запуск с начала.
  final VoidCallback? onFirstRun;

  /// Пройти «Возвращение» с начала.
  final VoidCallback? onReturn;

  /// Запустить игру и открыть поверх неё оверлей.
  final VoidCallback? onOverlay;

  /// Вид библиотеки и его выбор; «Пульт» — отдельным режимом.
  final EvLibraryView? view;
  final ValueChanged<EvLibraryView>? onView;
  final VoidCallback? onPult;

  /// Уже этого окна колонка разделов встаёт над ними и перестаёт
  /// быть липкой — `max-width:880px` в прототипе.
  static const narrow = 880.0;

  /// Ширина левой колонки.
  static const navWidth = 212.0;

  /// Те же состояния и подписи, что в панели прототипа.
  static final _states = [
    (EvHeroState.ready, 'Обычное состояние', 'установлена, можно играть'),
    (
      EvHeroState.notInstalled,
      'Не установлена',
      'есть в аккаунте, нет на диске',
    ),
    (
      EvHeroState.update,
      'Есть обновление',
      'патч ${sampleUpdate.bareVersion} · 1.8 ГБ',
    ),
    (EvHeroState.installing, 'Идёт установка', 'распаковка 41 %'),
    (EvHeroState.running, 'Игра запущена', 'кнопка стала статусом'),
    (EvHeroState.offline, 'Нет сети', 'локальное живёт, сетевое нет'),
    (EvHeroState.returned, 'Второй запуск', 'дайджест и точка сохранения'),
  ];

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _query = TextEditingController();
  final _anchors = <String, GlobalKey>{};
  ScrollController? _scroll;
  String? _current;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scroll = PrimaryScrollController.maybeOf(context);
    if (scroll == _scroll) return;
    _scroll?.removeListener(_spy);
    _scroll = scroll?..addListener(_spy);
  }

  @override
  void dispose() {
    _scroll?.removeListener(_spy);
    _query.dispose();
    super.dispose();
  }

  /// Где кончается полоса над экраном: раздел под ней считается открытым.
  double get _top =>
      MediaQuery.paddingOf(context).top +
      EvSpace.gutterFor(MediaQuery.sizeOf(context));

  /// Какой раздел сейчас наверху — его пункт в колонке и подсвечен.
  void _spy() {
    String? current;
    for (final MapEntry(key: id, value: key) in _anchors.entries) {
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      if (box.localToGlobal(Offset.zero).dy - 60 <= _top) current = id;
    }
    if (current != null && current != _current) {
      setState(() => _current = current);
    }
  }

  void _go(String id) {
    final box = _anchors[id]?.currentContext?.findRenderObject();
    final scroll = _scroll;
    if (box is! RenderBox || scroll == null || !scroll.hasClients) return;
    final target = scroll.offset + box.localToGlobal(Offset.zero).dy - _top;
    setState(() => _current = id);
    scroll.animateTo(
      target.clamp(0, scroll.position.maxScrollExtent),
      duration: MediaQuery.disableAnimationsOf(context)
          ? const Duration(milliseconds: 1)
          : EvMotion.screen,
      curve: EvMotion.easeOut,
    );
  }

  /// Настройки вне окна — в превью и тестах — показывают звук, который
  /// никуда не звучит.
  late final _silent = EvSound(out: const EvSilentOut());

  @override
  Widget build(BuildContext context) {
    final effects = EvEffectsScope.maybeOf(context);
    final sound = EvSoundScope.maybeOf(context) ?? _silent;
    final appearance = EvAppearanceScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([widget.settings, ?effects, sound]),
      builder: (context, _) {
        final sections = [
          ...evSettingsCatalog((
            appearance: appearance,
            effects: effects,
            sound: sound,
            settings: widget.settings,
            drives: widget.drives,
            ratio: widget.ratio,
            cloud: widget.cloud,
            hour: widget.hour ?? DateTime.now().hour,
          )),
          _development(),
        ];
        return _layout(
          context,
          sections,
          EvSettingsMatch.of(sections, _query.text),
        );
      },
    );
  }

  Widget _layout(
    BuildContext context,
    List<EvSettingSection> sections,
    EvSettingsMatch match,
  ) {
    final ev = context.ev;
    final window = MediaQuery.sizeOf(context);
    final gutter = EvSpace.gutterFor(window);
    final chrome = MediaQuery.paddingOf(context);
    final visible = [
      for (final s in sections)
        if (match.section(s)) s,
    ];
    final current = visible.any((s) => s.id == _current)
        ? _current
        : visible.firstOrNull?.id;

    final nav = SizedBox(
      width: SettingsPage.navWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EvSettingsSearch(
            controller: _query,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          for (final s in visible) ...[
            EvSettingsNavItem(
              icon: s.icon,
              label: s.title,
              active: s.id == current,
              onTap: () => _go(s.id),
            ),
            const SizedBox(height: 2),
          ],
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: Text(
              'Evaporate ${EvSettings.version}\n'
              'движок раздач ${EvSettings.engineVersion}',
              style: ev.text.data.copyWith(
                fontSize: 10,
                height: 1.7,
                color: ev.colors.ink4,
              ),
            ),
          ),
        ],
      ),
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (match.empty)
          const EvNothing(
            icon: EvIcons.search,
            title: 'Ничего не нашлось',
            detail: 'Попробуйте «скорость», «порт», «облако» или «ритуал»',
          ),
        for (final (i, s) in visible.indexed) ...[
          if (i > 0) const SizedBox(height: 30),
          _Section(
            key: _anchors[s.id] ??= GlobalKey(debugLabel: s.id),
            section: s,
            match: match,
          ),
        ],
      ],
    );

    final pad = EdgeInsets.fromLTRB(
      gutter,
      chrome.top + gutter,
      gutter,
      26 + chrome.bottom,
    );
    if (window.width < SettingsPage.narrow) {
      return SingleChildScrollView(
        primary: true,
        padding: pad,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [nav, const SizedBox(height: 24), body],
        ),
      );
    }
    // Колонка слева не прокручивается — это и есть `position: sticky`.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: gutter, top: chrome.top + gutter),
          child: nav,
        ),
        SizedBox(width: gutter),
        Expanded(
          child: SingleChildScrollView(
            primary: true,
            padding: pad.copyWith(left: 0),
            child: body,
          ),
        ),
      ],
    );
  }

  EvSettingSection _development() {
    final w = widget;
    EvSettingPanel states<T>(
      String label,
      String note,
      List<(T, String, String)> items,
      T value,
      ValueChanged<T> onTap,
    ) => EvSettingPanel(
      label: label,
      note: note,
      body: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (v, name, hint) in items)
            _StateRow(
              name: name,
              hint: hint,
              selected: v == value,
              onTap: () => onTap(v),
            ),
        ],
      ),
    );
    final friendPage = w.onFriendPage;
    final onCatalog = w.onCatalog;
    final onFirstRun = w.onFirstRun;
    final onOverlay = w.onOverlay;
    final onView = w.onView;
    final onPult = w.onPult;
    return EvSettingSection(
      id: 'dev',
      title: 'Разработка',
      icon: EvIcons.verified,
      panels: [
        if (onFirstRun != null)
          EvSettingPanel(
            label: 'Сценарий',
            note:
                'Восемь шагов от пустой библиотеки до запущенной игры. '
                'Листаются стрелками ← → и кнопками внизу окна',
            body: (_) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StateRow(
                  name: 'Первый запуск',
                  hint: '8 шагов · пусто → игра',
                  selected: false,
                  onTap: onFirstRun,
                ),
                if (w.onReturn != null)
                  _StateRow(
                    name: 'Возвращение',
                    hint: '4 шага · новости → продолжение',
                    selected: false,
                    onTap: w.onReturn!,
                  ),
              ],
            ),
          ),
        if (onOverlay != null)
          EvSettingPanel(
            label: 'В игре',
            note:
                'Поверх игры оверлей открывается по Shift+Tab. Здесь игры '
                'нет — отсюда он открывается вместе с запуском',
            body: (_) => _StateRow(
              name: 'Оверлей в игре',
              hint: 'кадры · друзья · фоновая загрузка',
              selected: false,
              onTap: onOverlay,
            ),
          ),
        if (onView != null && onPult != null)
          EvSettingPanel(
            label: 'Режимы',
            note:
                'Стена и Терминал — виды библиотеки, переключаются и в верхней '
                'полосе. Пульт забирает весь экран',
            body: (_) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StateRow(
                  name: 'B · Стена',
                  hint: 'плотная сетка, фильтры в шапке',
                  selected: w.view == EvLibraryView.wall,
                  onTap: () => onView(EvLibraryView.wall),
                ),
                _StateRow(
                  name: 'D · Терминал',
                  hint: 'таблица, сортировка, клавиатура',
                  selected: w.view == EvLibraryView.term,
                  onTap: () => onView(EvLibraryView.term),
                ),
                _StateRow(
                  name: 'C · Пульт',
                  hint: 'полный экран, геймпад · клавиша P',
                  selected: false,
                  onTap: onPult,
                ),
              ],
            ),
          ),
        if (onCatalog != null)
          states(
            'Каталог',
            'Пустой каталог — точка входа, а не заглушка. Чтение каталога '
                'при каждом старте длится 300 мс',
            [for (final v in EvCatalog.values) (v, v.label, v.hint)],
            w.catalog,
            onCatalog,
          ),
        states(
          'Состояние библиотеки',
          'Движка ещё нет: состояния героя переключаются здесь. '
              'В прототипе это панель «Состояния», в продукте её нет',
          SettingsPage._states,
          w.state,
          w.onState,
        ),
        states(
          'Состояние загрузок',
          'Шесть состояний очереди. «Сеть пропала» — состояние окна: '
              'его же увидит герой',
          [for (final v in EvDownloadsState.values) (v, v.label, v.hint)],
          w.downloads,
          w.onDownloads,
        ),
        states(
          'Состояние сохранений',
          'Облако, лента и расхождение версий. Разрешить конфликт можно '
              'по-настоящему — любой из трёх кнопок',
          [for (final v in EvSavesState.values) (v, v.label, v.hint)],
          w.saves,
          w.onSaves,
        ),
        states(
          'Состояние друзей',
          'Заявку можно принять по-настоящему. «Нет сети» здесь нет: это '
              'состояние окна, из библиотеки',
          [for (final v in EvFriendsState.values) (v, v.label, v.hint)],
          w.friendsState,
          w.onFriends,
        ),
        if (friendPage != null)
          states<EvPerson?>(
            'Профиль друга',
            'Открывается и из «Друзей» — кликом по любому из двенадцати. '
                'Здесь — два крайних случая',
            [
              (
                samplePeople[0],
                'Открытый профиль',
                'Антон К. · показывает всё',
              ),
              (
                samplePeople[6],
                'Закрытый профиль',
                'Игорь В. · скрыл часы и игру',
              ),
            ],
            // Страница друга открывается вместо настроек — выбранной
            // здесь она не остаётся.
            null,
            (p) => friendPage(p!),
          ),
        EvSettingPanel(
          label: 'Галерея компонентов',
          rows: [
            EvSettingRow(
              title: 'Галерея компонентов',
              detail: 'Все виджеты, перенесённые из макетов, на одной странице',
              control: (context) => EvMiniButton(
                label: 'Открыть',
                icon: EvIcons.go,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const GalleryPage()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Раздел: заголовок и панели. Строки, которых нет в выдаче поиска,
/// не рисуются; найденное в подписи подсвечено.
class _Section extends StatelessWidget {
  const _Section({super.key, required this.section, required this.match});

  final EvSettingSection section;
  final EvSettingsMatch match;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final panels = [
      for (final p in section.panels)
        if (match.panel(p)) p,
    ];
    final noteStyle = ev.text.body.copyWith(fontSize: 12.5, color: c.ink4);
    Widget panel(EvSettingPanel p) {
      final rows = match.rows(p);
      return EvPanel(
        glowCorner: p.glowCorner,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(p.label.toUpperCase(), style: ev.text.label),
            if (p.note != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ConstrainedBox(
                  // 62ch — мера строки пояснения в прототипе.
                  constraints: BoxConstraints(
                    maxWidth: evCharWidth(noteStyle) * 62,
                  ),
                  child: Text(p.note!, style: noteStyle),
                ),
              ),
            if (p.body != null) ...[
              const SizedBox(height: 14),
              p.body!(context),
            ],
            if (rows.isNotEmpty) const SizedBox(height: 6),
            for (final (i, r) in rows.indexed)
              AnimatedOpacity(
                duration: EvMotion.fast,
                opacity: r.dim ? .4 : 1,
                child: EvOption(
                  title: r.title,
                  description: r.detail,
                  highlight: match.highlight(r.title),
                  last: i == rows.length - 1,
                  control: r.control(context),
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EvSettingsHeader(section.title, onReset: section.onReset),
        const SizedBox(height: 14),
        for (final (i, p) in panels.indexed) ...[
          if (i > 0) const SizedBox(height: 13),
          panel(p),
        ],
      ],
    );
  }
}

/// Строка списка состояний: точка, название и чем это состояние
/// отличается.
class _StateRow extends StatefulWidget {
  const _StateRow({
    required this.name,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_StateRow> createState() => _StateRowState();
}

class _StateRowState extends State<_StateRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final lit = widget.selected || _hover;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: EvFocusable(
        onActivate: widget.onTap,
        radius: ev.radii.r2,
        child: Semantics(
          button: true,
          selected: widget.selected,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: ev.radii.b2,
                color: _hover ? c.ink.withValues(alpha: .04) : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.selected ? c.hot2 : c.line,
                      boxShadow: widget.selected
                          ? [BoxShadow(color: c.hot2, blurRadius: 8)]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Text(
                    widget.name,
                    style: ev.text.body.copyWith(
                      fontSize: 13,
                      color: lit ? c.ink : c.ink2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: ev.text.data.copyWith(
                        fontSize: 10.5,
                        color: c.ink4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
