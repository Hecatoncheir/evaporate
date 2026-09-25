import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../art/ev_art.dart';
import '../art/key_art.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../glass/ev_droplet.dart';
import '../glass/ev_glass.dart';
import '../widgets/ev_icon.dart';
import 'ev_top_bar.dart' show EvKey;

/// Строка палитры: игра, раздел или команда.
@immutable
class EvCommand {
  const EvCommand({
    required this.title,
    required this.subtitle,
    required this.onRun,
    this.hint = '↵ выполнить',
    this.cover,
    this.icon = EvIcons.go,
    this.onLaunch,
  });

  final String title;

  /// Жанр, «раздел», «команда». Поиск идёт и по нему: «хоррор» находит игру.
  final String subtitle;

  final VoidCallback onRun;
  final String hint;

  /// Обложка игры миниатюрой слева; без неё слева иконка.
  final (EvCoverPalette, int)? cover;

  final String icon;

  /// `Shift+Enter` и клик с Shift: запустить игру сразу, минуя её
  /// карточку. `null` — то же, что Enter.
  final VoidCallback? onLaunch;
}

/// Открывает палитру «Поиск и команды» поверх окна.
///
/// Как в прототипе: затемнение с размытием, панель 620 px на 15 % высоты
/// сверху, не больше девяти строк. `Enter` выполняет строку, `Shift+Enter`
/// запускает игру. Закрывается по Esc, клику мимо панели и после
/// выполнения команды.
///
/// Панель — самое толстое стекло в системе: под ней окно не просто
/// темнеет, а уходит в глубину — размывается и теряет цвет.
Future<void> showEvPalette(BuildContext context, List<EvCommand> commands) {
  final reduced = MediaQuery.disableAnimationsOf(context);
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: const Color(0x99040408),
      barrierLabel: 'Закрыть поиск',
      transitionDuration: reduced ? Duration.zero : EvMotion.popover,
      reverseTransitionDuration: reduced ? Duration.zero : EvMotion.fast,
      pageBuilder: (context, animation, secondaryAnimation) =>
          EvPalette(commands: commands),
      transitionsBuilder: _paletteTransition,
    ),
  );
}

// Подложка проявляется за 220 мс, панель опускается на 12 px и дорастает
// с 98 % за все 280.
Widget _paletteTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) => FadeTransition(
  opacity: animation.drive(CurveTween(curve: const Interval(0, 220 / 280))),
  child: MatrixTransition(
    animation: animation.drive(CurveTween(curve: EvMotion.easeOut)),
    alignment: Alignment.topCenter,
    onTransform: (t) {
      final s = 0.98 + 0.02 * t;
      return Matrix4.translationValues(0, -12 * (1 - t), 0)
        ..multiply(Matrix4.diagonal3Values(s, s, 1));
    },
    child: child,
  ),
);

class EvPalette extends StatefulWidget {
  const EvPalette({super.key, required this.commands});

  final List<EvCommand> commands;

  @override
  State<EvPalette> createState() => _EvPaletteState();
}

class _EvPaletteState extends State<EvPalette> {
  static const _limit = 9;
  static const _rowHeight = 62.0;
  static const _listPad = 7.0;

  final _query = TextEditingController();
  final _scroll = ScrollController();
  late List<EvCommand> _results = _filter('');
  int _selected = 0;
  bool _closing = false;

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<EvCommand> _filter(String query) {
    final q = query.trim().toLowerCase();
    return widget.commands
        .where(
          (c) =>
              q.isEmpty ||
              c.title.toLowerCase().contains(q) ||
              c.subtitle.toLowerCase().contains(q),
        )
        .take(_limit)
        .toList();
  }

  void _onQuery(String query) {
    setState(() {
      _results = _filter(query);
      _selected = 0;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _move(int delta) {
    if (_results.isEmpty) return;
    setState(() {
      _selected = (_selected + delta + _results.length) % _results.length;
    });
    _reveal();
  }

  /// Держит выбранную строку в видимой части списка.
  void _reveal() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    final top = _listPad + _selected * _rowHeight;
    final bottom = top + _rowHeight + _listPad;
    var target = p.pixels;
    if (top - _listPad < p.pixels) {
      target = top - _listPad;
    } else if (bottom > p.pixels + p.viewportDimension) {
      target = bottom - p.viewportDimension;
    }
    _scroll.jumpTo(target.clamp(0, p.maxScrollExtent));
  }

  /// Выполнить строку [index]; [launch] — запустить игру вместо Enter.
  ///
  /// Выполняется один раз: `Enter` может дойти и сюда, и до поля ввода
  /// как отправка, а второй вызов закрыл бы уже не палитру, а окно под ней.
  void _run(int index, {bool launch = false}) {
    if (_closing || index < 0 || index >= _results.length) return;
    _closing = true;
    final command = _results[index];
    Navigator.of(context).pop();
    (launch ? command.onLaunch ?? command.onRun : command.onRun)();
  }

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final window = MediaQuery.sizeOf(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.enter, shift: true): () =>
            _run(_selected, launch: true),
        const SingleActivator(
          LogicalKeyboardKey.numpadEnter,
          shift: true,
        ): () =>
            _run(_selected, launch: true),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Stack(
        children: [
          // Мимо панели — закрыть. Размытие под затемнением: окно за
          // палитрой уходит в глубину, а не просто темнеет, и заодно
          // теряет цвет — как за матовым стеклом в iOS.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: BackdropFilter(
                filter: ui.ImageFilter.compose(
                  outer: evGlassColorFilter(0.8, 0.9)!,
                  inner: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(
                top: math.min(window.height * 0.15, 130),
              ),
              child: SizedBox(
                width: math.min(620, window.width * 0.92),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: window.height * 0.7),
                  child: Semantics(
                    scopesRoute: true,
                    namesRoute: true,
                    explicitChildNodes: true,
                    label: 'Поиск и команды',
                    child: _panel(ev),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(EvTheme ev) {
    final c = ev.colors;
    final small = ev.text.data.copyWith(color: c.ink4, fontSize: 10.5);
    return Material(
      type: MaterialType.transparency,
      child: EvGlass(
        style: EvGlassStyle.raised,
        borderRadius: ev.radii.b4,
        shadows: const [
          BoxShadow(
            color: Color(0xBF000000),
            blurRadius: 100,
            offset: Offset(0, 40),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.lineSoft)),
              ),
              child: Row(
                children: [
                  EvIcon(EvIcons.search, size: 17, color: c.ink4),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _query,
                      autofocus: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      onChanged: _onQuery,
                      onSubmitted: (_) => _run(_selected),
                      // без этого поле теряет фокус после Enter,
                      // и стрелки перестают работать
                      onEditingComplete: () {},
                      cursorColor: c.hot2,
                      style: ev.text.body.copyWith(
                        color: c.ink,
                        fontSize: 16,
                        height: 1.3,
                      ),
                      decoration: InputDecoration.collapsed(
                        hintText: 'Игра, раздел или команда…',
                        hintStyle: ev.text.body.copyWith(
                          color: c.ink4,
                          fontSize: 16,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const EvKey('ESC', dense: true),
                ],
              ),
            ),
            Flexible(
              child: _results.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(22),
                      child: Center(
                        child: Text(
                          'ничего не найдено',
                          style: ev.text.data.copyWith(
                            color: c.ink4,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                  : _list(ev),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.lineSoft)),
              ),
              child: Row(
                children: [
                  Text('↑↓ выбрать', style: small),
                  const SizedBox(width: 16),
                  Text('↵ открыть', style: small),
                  const SizedBox(width: 16),
                  Text('⇧↵ запустить', style: small),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Список с каплей под выбранной строкой. Капля лежит в тех же
  /// координатах, что и список, поэтому при прокрутке едет вместе с ним.
  Widget _list(EvTheme ev) => LayoutBuilder(
    builder: (context, box) => Stack(
      children: [
        AnimatedBuilder(
          animation: _scroll,
          builder: (context, _) {
            final offset = _scroll.hasClients ? _scroll.offset : 0.0;
            return EvDroplet(
              rect: Rect.fromLTWH(
                _listPad,
                _listPad + _selected * _rowHeight - offset,
                box.maxWidth - _listPad * 2,
                _rowHeight,
              ),
              radius: ev.radii.b2,
              duration: EvMotion.popover,
            );
          },
        ),
        ListView.builder(
          controller: _scroll,
          shrinkWrap: true,
          padding: const EdgeInsets.all(_listPad),
          itemExtent: _rowHeight,
          itemCount: _results.length,
          itemBuilder: (context, i) => _PaletteRow(
            command: _results[i],
            selected: i == _selected,
            onHover: () {
              if (_selected != i) setState(() => _selected = i);
            },
            onTap: () =>
                _run(i, launch: HardwareKeyboard.instance.isShiftPressed),
          ),
        ),
      ],
    ),
  );
}

class _PaletteRow extends StatelessWidget {
  const _PaletteRow({
    required this.command,
    required this.selected,
    required this.onHover,
    required this.onTap,
  });

  final EvCommand command;
  final bool selected;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final thumbRadius = BorderRadius.circular(math.min(ev.radii.r3, 6));
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      // Именно движение, а не вход: когда стрелки прокручивают список,
      // строки сами въезжают под неподвижный курсор — вход сработал бы
      // и перехватил выбор у клавиатуры.
      onHover: (_) => onHover(),
      child: GestureDetector(
        onTap: onTap,
        child: Semantics(
          button: true,
          selected: selected,
          child: Padding(
            // Выбранную строку помечает капля стекла под списком.
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: thumbRadius,
                    color: c.surface,
                    border: Border.all(color: c.line),
                  ),
                  child: ClipRRect(
                    borderRadius: thumbRadius,
                    child: switch (command.cover) {
                      (final palette, final seed) => EvCover(
                        palette: palette,
                        seed: seed,
                      ),
                      null => Center(
                        child: EvIcon(command.icon, size: 15, color: c.ink4),
                      ),
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        command.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ev.text.body.copyWith(
                          color: selected ? c.hot2 : c.ink,
                          fontSize: 13.5,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        command.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ev.text.data.copyWith(
                          color: c.ink4,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  command.hint,
                  style: ev.text.data.copyWith(color: c.ink4, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
