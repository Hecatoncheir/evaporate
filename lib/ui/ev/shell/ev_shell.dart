import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../atmosphere/ev_atmosphere.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../glass/ev_scroll_edge.dart';
import 'ev_hints_bar.dart';
import 'ev_palette.dart';
import 'ev_rail.dart';
import 'ev_section.dart';
import 'ev_top_bar.dart';

/// Текущий раздел окна.
///
/// Живёт снаружи каркаса, как `TabController`: раздел меняют рейл, клавиши
/// и команды палитры, а команды собираются там, где каркаса ещё нет.
class EvShellController extends ChangeNotifier {
  EvShellController({
    EvSection initial = EvSection.library,
    this.sections = EvSection.values,
  }) : _section = initial;

  /// Разделы, между которыми ходят рейл, цифры и `Ctrl+Tab`. Приложение
  /// прячет те, у которых нет данных: друзей и профиль.
  final List<EvSection> sections;

  EvSection _section;
  EvSection get section => _section;

  Object? _detail;
  String? _crumb;

  /// Страница внутри раздела — профиль друга внутри «Друзей». `null` —
  /// сам раздел.
  Object? get detail => _detail;

  /// Что стоит в хлебной крошке вместо названия раздела: имя друга.
  String? get crumb => _crumb;

  /// Открыть страницу [detail] внутри [section].
  void open(EvSection section, Object detail, {required String crumb}) {
    _section = section;
    _detail = detail;
    _crumb = crumb;
    notifyListeners();
  }

  /// Назад со вложенной страницы в раздел. Ничего не открыто — `false`.
  bool back() {
    if (_detail == null) return false;
    _detail = null;
    _crumb = null;
    notifyListeners();
    return true;
  }

  final _reselected = ValueNotifier<int>(0);

  /// Выбран раздел, который уже открыт: экран возвращается к началу.
  Listenable get reselected => _reselected;

  /// Выбор раздела закрывает вложенную страницу — и того же раздела
  /// тоже: рейл ведёт к разделу, а не к последней открытой в нём странице.
  void go(EvSection section) {
    if (section == _section && !back()) {
      _reselected.value++;
      return;
    }
    _detail = null;
    _crumb = null;
    _section = section;
    notifyListeners();
  }

  /// По кругу: библиотека → … → последний из [sections] → библиотека.
  void next() => _step(1);

  void previous() => _step(-1);

  void _step(int delta) {
    final at = sections.indexOf(_section);
    go(sections[(at + delta) % sections.length]);
  }

  @override
  void dispose() {
    _reselected.dispose();
    super.dispose();
  }
}

/// Каркас окна: рейл, верхняя полоса, экран раздела и строка подсказок
/// поверх фона.
///
/// Уже [EvSpace.narrowBreakpoint] рейл уходит вниз, а строка подсказок
/// пропадает — как в прототипе. На Windows до этого не доходит: окно не
/// сжимается меньше 1280 × 720, это задаёт раннер.
///
/// Клавиши — те же, что в прототипе и в строке подсказок:
/// * `1`…`6` — раздел по номеру;
/// * `Ctrl+Tab` / `Ctrl+Shift+Tab` — следующий и предыдущий по кругу;
/// * `/` или `Ctrl+K` — поиск и команды.
///
/// Пока фокус в поле ввода, цифры и слэш печатаются, а не переключают.
class EvShell extends StatefulWidget {
  const EvShell({
    super.key,
    required this.controller,
    this.pageBuilder,
    this.body,
    required this.initials,
    required this.userName,
    this.commands = const [],
    this.commandsOf,
    this.windowControls,
    this.windowGrip,
    this.hintsBar,
    this.status = const [],
    this.friendsOnline,
    this.downloadsActive,
    this.libraryTools,
    this.keys = const {},
  });

  final EvShellController controller;

  /// Экран раздела. Его главный вертикальный скролл должен быть
  /// `primary: true`: тогда повторный выбор раздела возвращает экран
  /// к началу.
  final Widget Function(BuildContext context, EvSection section)? pageBuilder;

  /// Постоянное содержимое вместо смены экранов. Приложение держит свои
  /// разделы стопкой само: их состояние переживает переход, а скрытый
  /// раздел знает, что он скрыт. Задано — [pageBuilder] не нужен.
  final Widget? body;

  final String initials;
  final String userName;

  /// Содержимое палитры поиска.
  final List<EvCommand> commands;

  /// Содержимое палитры, собранное в миг открытия: список игр меняется, а
  /// перестраивать каркас на каждую его правку незачем. Задано — вместо
  /// [commands].
  final List<EvCommand> Function(BuildContext context)? commandsOf;

  /// Клавиши окна справа в верхней полосе — видны при любой ширине.
  final Widget? windowControls;

  /// Подложка, за которую тянут окно: под верхней полосой и рейлом.
  final WidgetBuilder? windowGrip;

  /// Строка подсказок вместо образцовой.
  final Widget? hintsBar;

  /// Показатели справа в верхней полосе. В узком окне не показываются.
  final List<Widget> status;

  final int? friendsOnline;
  final int? downloadsActive;

  /// Переключатель видов за крошкой — только на самой библиотеке.
  final Widget? libraryTools;

  /// Клавиши без модификаторов сверх своих: `P` — «Пульт». По физической
  /// клавише, чтобы работало и в русской раскладке, где на ней «З».
  final Map<PhysicalKeyboardKey, VoidCallback> keys;

  @override
  State<EvShell> createState() => _EvShellState();
}

class _EvShellState extends State<EvShell> {
  // Область фокуса, а не просто узел. Поле ввода по Enter снимает с себя
  // фокус и отдаёт его ближайшей области: без своей это был бы маршрут
  // над каркасом, и клавиши каркаса перестали бы доходить до обработчика.
  final _scope = FocusScopeNode(debugLabel: 'EvShell');

  bool _paletteOpen = false;

  static final _digits = {
    LogicalKeyboardKey.digit1: 0,
    LogicalKeyboardKey.digit2: 1,
    LogicalKeyboardKey.digit3: 2,
    LogicalKeyboardKey.digit4: 3,
    LogicalKeyboardKey.digit5: 4,
    LogicalKeyboardKey.digit6: 5,
    LogicalKeyboardKey.numpad1: 0,
    LogicalKeyboardKey.numpad2: 1,
    LogicalKeyboardKey.numpad3: 2,
    LogicalKeyboardKey.numpad4: 3,
    LogicalKeyboardKey.numpad5: 4,
    LogicalKeyboardKey.numpad6: 5,
  };

  EvShellController get _controller => widget.controller;

  @override
  void dispose() {
    _scope.dispose();
    super.dispose();
  }

  Future<void> _openPalette() async {
    if (_paletteOpen) return;
    _paletteOpen = true;
    try {
      await showEvPalette(
        context,
        widget.commandsOf?.call(context) ?? widget.commands,
      );
    } finally {
      _paletteOpen = false;
    }
  }

  /// Фокус в поле ввода: символы принадлежат ему.
  bool get _typing {
    final focused = FocusManager.instance.primaryFocus?.context;
    return focused != null &&
        (focused.widget is EditableText ||
            focused.findAncestorWidgetOfExactType<EditableText>() != null);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    final key = event.logicalKey;

    // Ctrl+Tab ничего не печатает, поэтому работает и из поля ввода.
    if (key == LogicalKeyboardKey.tab && keys.isControlPressed) {
      keys.isShiftPressed ? _controller.previous() : _controller.next();
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent || _typing) return KeyEventResult.ignored;
    if (keys.isAltPressed || keys.isMetaPressed) return KeyEventResult.ignored;

    // Слэш ищется и по символу, и по клавише: в русской раскладке на месте
    // «/» стоит точка, а сам слэш набирается с Shift.
    final ctrl = keys.isControlPressed;
    final search = ctrl
        ? key == LogicalKeyboardKey.keyK ||
              event.physicalKey == PhysicalKeyboardKey.keyK
        : event.character == '/' ||
              (event.physicalKey == PhysicalKeyboardKey.slash &&
                  !keys.isShiftPressed);
    if (search) {
      _openPalette();
      return KeyEventResult.handled;
    }

    if (ctrl || keys.isShiftPressed) return KeyEventResult.ignored;
    // Esc — «Назад» из строки подсказок: с чужой страницы к списку.
    if (key == LogicalKeyboardKey.escape) {
      return _controller.back()
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    final extra = widget.keys[event.physicalKey];
    if (extra != null) {
      extra();
      return KeyEventResult.handled;
    }
    final index = _digits[key];
    final sections = _controller.sections;
    if (index == null || index >= sections.length) {
      return KeyEventResult.ignored;
    }
    _controller.go(sections[index]);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.evc;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return FocusScope(
      node: _scope,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: c.ground,
        body: EvAtmosphere(
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final section = _controller.section;
              final sections = _controller.sections;
              final page =
                  widget.body ??
                  AnimatedSwitcher(
                    duration: reduced ? Duration.zero : EvMotion.screenSettle,
                    reverseDuration: reduced ? Duration.zero : EvMotion.fast,
                    layoutBuilder: _stackPages,
                    transitionBuilder: _pageTransition,
                    child: _SectionHost(
                      key: ValueKey((section, _controller.detail)),
                      reselected: _controller.reselected,
                      child: Builder(
                        builder: (context) =>
                            widget.pageBuilder!(context, section),
                      ),
                    ),
                  );
              return LayoutBuilder(
                builder: (context, box) {
                  final narrow = box.maxWidth < EvSpace.narrowBreakpoint;
                  final rail = narrow ? 0.0 : EvSpace.railWidth;
                  final bottom = narrow
                      ? EvSpace.bottomNavHeight
                      : EvSpace.hintsHeight;
                  return Stack(
                    children: [
                      // Экран лежит под каркасом во всю высоту: содержимое
                      // уходит под стекло полос, а не упирается в него.
                      // Сколько места занято каркасом, экраны узнают из
                      // отступов MediaQuery.
                      Positioned.fill(
                        left: rail,
                        child: MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            padding: EdgeInsets.only(
                              top: EvSpace.topBarHeight,
                              bottom: bottom,
                            ),
                          ),
                          child: page,
                        ),
                      ),
                      // Все стёкла каркаса читают фон один раз на всех:
                      // они не перекрываются, а нарисованы после экрана.
                      BackdropGroup(
                        child: Stack(
                          children: [
                            Positioned(
                              left: rail,
                              right: 0,
                              top: EvSpace.topBarHeight,
                              child: const EvScrollEdge(),
                            ),
                            Positioned(
                              left: rail,
                              right: 0,
                              bottom: bottom,
                              child: const EvScrollEdge(fromTop: false),
                            ),
                            Positioned(
                              left: rail,
                              right: 0,
                              top: 0,
                              child: EvTopBar(
                                section:
                                    _controller.crumb ??
                                    section.labelOf(L.of(context)),
                                onSearch: _openPalette,
                                end: widget.windowControls,
                                underlay: widget.windowGrip?.call(context),
                                // Плашкам нужно место рядом с поиском и
                                // клавишами окна: в узком окне их нет.
                                trailing: box.maxWidth < EvTopBar.statusFrom
                                    ? const []
                                    : widget.status,
                                // На узком окне ему, как и плашкам,
                                // нет места; до 1080 px — тоже: он
                                // наезжал бы на поиск.
                                tools:
                                    box.maxWidth >= EvTopBar.toolsFrom &&
                                        section == EvSection.library &&
                                        _controller.detail == null
                                    ? widget.libraryTools
                                    : null,
                              ),
                            ),
                            if (narrow)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: EvBottomNav(
                                  key: const ValueKey('navigation-rack'),
                                  sections: sections,
                                  current: section,
                                  onSelect: _controller.go,
                                  initials: widget.initials,
                                ),
                              )
                            else ...[
                              Positioned(
                                left: 0,
                                top: 0,
                                bottom: 0,
                                child: EvRail(
                                  key: const ValueKey('navigation-rack'),
                                  friends: sections.contains(EvSection.friends),
                                  profile: sections.contains(EvSection.profile),
                                  underlay: widget.windowGrip?.call(context),
                                  current: section,
                                  onSelect: _controller.go,
                                  initials: widget.initials,
                                  userName: widget.userName,
                                  friendsOnline: widget.friendsOnline,
                                  downloadsActive: widget.downloadsActive,
                                ),
                              ),
                              Positioned(
                                left: EvSpace.railWidth,
                                right: 0,
                                bottom: 0,
                                child: widget.hintsBar ?? const EvHintsBar(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// Уходящий и приходящий экраны лежат друг на друге во всю площадь.
// Функции верхнего уровня, а не замыкания: AnimatedSwitcher сравнивает
// построители и пересобрал бы переходы на каждой сборке каркаса.
Widget _stackPages(Widget? current, List<Widget> previous) =>
    Stack(fit: StackFit.expand, children: [...previous, ?current]);

Widget _pageTransition(Widget child, Animation<double> animation) =>
    _PageTransition(animation: animation, child: child);

/// Смена раздела из прототипа: экран проявляется за 340 мс, поднимается
/// на 10 px и дорастает с 99,4 % за 440. Уходящий гаснет линейно за 200.
class _PageTransition extends StatefulWidget {
  const _PageTransition({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  State<_PageTransition> createState() => _PageTransitionState();
}

class _PageTransitionState extends State<_PageTransition> {
  late CurvedAnimation _fade;
  late CurvedAnimation _move;

  @override
  void initState() {
    super.initState();
    _curve();
  }

  @override
  void didUpdateWidget(_PageTransition old) {
    super.didUpdateWidget(old);
    if (old.animation != widget.animation) {
      _dispose();
      _curve();
    }
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _curve() {
    final fadeEnd =
        EvMotion.screen.inMilliseconds / EvMotion.screenSettle.inMilliseconds;
    _fade = CurvedAnimation(
      parent: widget.animation,
      curve: Interval(0, fadeEnd, curve: EvMotion.easeOut),
      reverseCurve: Curves.linear,
    );
    _move = CurvedAnimation(
      parent: widget.animation,
      curve: EvMotion.easeOut,
      reverseCurve: Curves.linear,
    );
  }

  void _dispose() {
    _fade.dispose();
    _move.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: MatrixTransition(
      animation: _move,
      onTransform: (t) {
        final s = 0.994 + 0.006 * t;
        return Matrix4.translationValues(0, 10 * (1 - t), 0)
          ..multiply(Matrix4.diagonal3Values(s, s, 1));
      },
      child: widget.child,
    ),
  );
}

/// Держит скролл экрана и возвращает его к началу при повторном выборе
/// раздела. У каждого экрана свой контроллер: уходящий экран ещё гаснет,
/// когда приходящий уже строится.
class _SectionHost extends StatefulWidget {
  const _SectionHost({
    super.key,
    required this.reselected,
    required this.child,
  });

  final Listenable reselected;
  final Widget child;

  @override
  State<_SectionHost> createState() => _SectionHostState();
}

class _SectionHostState extends State<_SectionHost> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.reselected.addListener(_toTop);
  }

  @override
  void didUpdateWidget(_SectionHost old) {
    super.didUpdateWidget(old);
    if (old.reselected != widget.reselected) {
      old.reselected.removeListener(_toTop);
      widget.reselected.addListener(_toTop);
    }
  }

  @override
  void dispose() {
    widget.reselected.removeListener(_toTop);
    _scroll.dispose();
    super.dispose();
  }

  void _toTop() {
    if (!_scroll.hasClients || _scroll.offset == 0) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(0);
    } else {
      _scroll.animateTo(
        0,
        duration: EvMotion.screenSettle,
        curve: EvMotion.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) => PrimaryScrollController(
    controller: _scroll,
    // Только явный `primary: true`: вложенные списки не должны случайно
    // подцепить контроллер экрана.
    automaticallyInheritForPlatforms: const {},
    child: widget.child,
  );
}
