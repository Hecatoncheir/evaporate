import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../shell/ev_top_bar.dart' show EvKey;
import '../util/plural.dart';
import '../widgets/ev_controls.dart';
import '../widgets/ev_focusable.dart';
import '../widgets/ev_icon.dart';
import '../widgets/ev_surfaces.dart';
import 'settings_data.dart';

/// Три темы карточками: полоса цвета, название и характер. Выбранная —
/// в янтарной кромке.
class EvSkinCards extends StatelessWidget {
  const EvSkinCards({super.key, required this.value, required this.onChanged});

  final EvSkin value;
  final ValueChanged<EvSkin> onChanged;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    Widget card(EvSkin s) {
      final on = s == value;
      final k = s.colors;
      return EvFocusable(
        onActivate: () => onChanged(s),
        radius: ev.radii.r3,
        child: Semantics(
          button: true,
          selected: on,
          label: 'Тема ${s.label}',
          child: AnimatedContainer(
            duration: EvMotion.fast,
            padding: const EdgeInsets.all(11),
            // Кольцо выбранной темы — второй кромкой, а не тенью: тень
            // во Flutter рисуется и под прозрачной карточкой и залила бы
            // её целиком, CSS под элементом тень не рисует.
            decoration: BoxDecoration(
              borderRadius: ev.radii.b3,
              color: on ? c.hot1.withValues(alpha: .06) : null,
              border: Border.all(
                color: on ? c.hot1.withValues(alpha: .6) : c.line,
                width: on ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: ev.radii.b2,
                    gradient: LinearGradient(
                      // 120° в CSS
                      begin: const Alignment(-.87, -.5),
                      end: const Alignment(.87, .5),
                      colors: [k.ground, k.hotDeep, k.hot1, k.hot2],
                      stops: const [0, .45, .77, 1],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  s.label.toUpperCase(),
                  style: ev.text.dsp(
                    ev.text.section,
                    size: 11,
                    letterSpacing: 11 * .14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.hint,
                  style: ev.text.data.copyWith(fontSize: 10, color: c.ink4),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        for (final (i, s) in EvSkin.values.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: card(s)),
        ],
      ],
    );
  }
}

/// Расписание скорости: 24 часа, которые красятся курсором. Нажатие
/// переключает час, протяжка красит все часы под курсором в тот же цвет.
/// Янтарные — без ограничения, серые — предел. Точка сверху — сейчас.
class EvSchedule extends StatefulWidget {
  const EvSchedule({
    super.key,
    required this.hours,
    required this.now,
    required this.onHour,
  });

  final List<bool> hours;

  /// Текущий час.
  final int now;

  final void Function(int hour, bool unlimited) onHour;

  static const gap = 3.0;
  static const height = 42.0;

  @override
  State<EvSchedule> createState() => _EvScheduleState();
}

class _EvScheduleState extends State<EvSchedule> {
  bool? _paint;

  int _hourAt(double x, double width) {
    final step = (width + EvSchedule.gap) / 24;
    return (x / step).floor().clamp(0, 23);
  }

  void _start(double x, double width) {
    final h = _hourAt(x, width);
    _paint = !widget.hours[h];
    widget.onHour(h, _paint!);
  }

  void _move(double x, double width) {
    if (_paint == null) return;
    final h = _hourAt(x, width);
    if (widget.hours[h] != _paint) widget.onHour(h, _paint!);
  }

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return Semantics(
      label: 'Расписание скорости по часам',
      child: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          final cell = (width - EvSchedule.gap * 23) / 24;
          // Сырые события указателя, как `pointerdown/move` в прототипе:
          // распознаватель протяжки отдал бы начало уже после сдвига,
          // и первый час оставался бы незакрашенным.
          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => _start(e.localPosition.dx, width),
            onPointerMove: (e) => _move(e.localPosition.dx, width),
            onPointerUp: (_) => _paint = null,
            onPointerCancel: (_) => _paint = null,
            child: SizedBox(
              height: EvSchedule.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var h = 0; h < 24; h++)
                    Positioned(
                      left: h * (cell + EvSchedule.gap),
                      width: cell,
                      top: 0,
                      bottom: 0,
                      child: _Hour(
                        hour: h,
                        unlimited: widget.hours[h],
                        now: h == widget.now,
                      ),
                    ),
                  // Точка над текущим часом.
                  Positioned(
                    left: widget.now * (cell + EvSchedule.gap) + cell / 2 - 2,
                    top: -6,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.cool,
                        boxShadow: [BoxShadow(color: c.cool, blurRadius: 8)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Hour extends StatelessWidget {
  const _Hour({required this.hour, required this.unlimited, required this.now});

  final int hour;
  final bool unlimited;
  final bool now;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return Semantics(
      label: '$hour:00 · ${unlimited ? 'без ограничения' : 'с пределом'}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: unlimited ? null : c.ink.withValues(alpha: .07),
          gradient: unlimited
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [c.hot1, c.hotDeep],
                )
              : null,
          boxShadow: unlimited
              ? [BoxShadow(color: c.hot1.withValues(alpha: .4), blurRadius: 14)]
              : null,
        ),
        child: hour % 3 == 0
            ? Text(
                hour.toString().padLeft(2, '0'),
                style: ev.text.data.copyWith(
                  fontSize: 8.5,
                  color: unlimited ? const Color(0xFF2A1000) : c.ink4,
                ),
              )
            : null,
      ),
    );
  }
}

/// Подпись под расписанием: что значат цвета и который час.
class EvScheduleLegend extends StatelessWidget {
  const EvScheduleLegend({super.key, required this.now});

  final int now;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final style = ev.text.data.copyWith(fontSize: 10.5, color: c.ink4);
    Widget swatch(bool full, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: full ? null : c.ink.withValues(alpha: .1),
            gradient: full
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [c.hot1, c.hotDeep],
                  )
                : null,
          ),
        ),
        const SizedBox(width: 7),
        Text(label, style: style),
      ],
    );
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        swatch(true, 'без ограничения'),
        swatch(false, 'предел ${EvSettings.limitMb} МБ/с'),
        Text(
          'сейчас ${now.toString().padLeft(2, '0')}:00',
          style: style.copyWith(color: c.cool),
        ),
      ],
    );
  }
}

/// Папка с играми: путь, что в ней, полоса занятости диска и остаток.
class EvDriveRow extends StatelessWidget {
  const EvDriveRow({super.key, required this.drive});

  final EvDrive drive;

  /// Выше этого диск почти полон — полоса желтеет.
  static const nearlyFull = .85;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final d = drive;
    final count = d.games.length;
    final note = d.installsHere
        ? 'сюда ставится новое'
        : d.readOnly
        ? 'только чтение'
        : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: ev.radii.b2,
        border: Border.all(color: c.lineSoft),
        color: c.ink.withValues(alpha: .022),
      ),
      child: Row(
        children: [
          EvIcon(EvIcons.drive, size: 17, color: c.ink3),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  d.path,
                  style: ev.text.data.copyWith(fontSize: 12.5, color: c.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    ruCount(count, 'игра', 'игры', 'игр'),
                    '${d.gamesGb.round()} ГБ',
                    ?note,
                  ].join(' · '),
                  style: ev.text.data.copyWith(fontSize: 10, color: c.ink4),
                ),
                const SizedBox(height: 8),
                EvBar(
                  d.used,
                  height: 4,
                  tone: d.used > nearlyFull ? EvBarTone.stall : EvBarTone.hot,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'свободно',
                style: ev.text.data.copyWith(fontSize: 9.5, color: c.ink4),
              ),
              Text(
                '${d.freeGb.round()} ГБ',
                style: ev.text.mono(
                  ev.text.data,
                  size: 12,
                  weight: FontWeight.w500,
                  color: EvColors.ok,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Клавиши строки — те же колпачки, что в строке подсказок.
class EvKeyCaps extends StatelessWidget {
  const EvKeyCaps(this.keys, {super.key});

  final List<String> keys;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (i, k) in keys.indexed) ...[
        if (i > 0) const SizedBox(width: 5),
        EvKey(k),
      ],
    ],
  );
}

/// Поиск по настройкам. Esc очищает и отпускает фокус.
class EvSettingsSearch extends StatefulWidget {
  const EvSettingsSearch({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  State<EvSettingsSearch> createState() => _EvSettingsSearchState();
}

class _EvSettingsSearchState extends State<EvSettingsSearch> {
  late final _focus = FocusNode(onKeyEvent: _onKey);

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    widget.controller.clear();
    widget.onChanged('');
    node.unfocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final focused = _focus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: EvMotion.ease,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: ev.radii.b2,
        color: c.ink.withValues(alpha: .025),
        border: Border.all(
          color: focused ? c.hot1.withValues(alpha: .5) : c.line,
        ),
        boxShadow: focused
            ? [BoxShadow(color: c.hot1.withValues(alpha: .16), blurRadius: 20)]
            : null,
      ),
      child: Row(
        children: [
          EvIcon(EvIcons.search, size: 15, color: c.ink4),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              onChanged: widget.onChanged,
              autocorrect: false,
              enableSuggestions: false,
              cursorColor: c.hot2,
              style: ev.text.body.copyWith(fontSize: 13, color: c.ink),
              decoration: InputDecoration.collapsed(
                hintText: 'Найти настройку',
                hintStyle: ev.text.body.copyWith(fontSize: 13, color: c.ink4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Пункт левой колонки: знак и название раздела. Текущий — янтарная черта
/// у кромки и тёплая подложка.
class EvSettingsNavItem extends StatefulWidget {
  const EvSettingsNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<EvSettingsNavItem> createState() => _EvSettingsNavItemState();
}

class _EvSettingsNavItemState extends State<EvSettingsNavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final on = widget.active;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: EvFocusable(
        onActivate: widget.onTap,
        radius: ev.radii.r2,
        child: Semantics(
          button: true,
          selected: on,
          child: AnimatedContainer(
            duration: EvMotion.fast,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: ev.radii.b2,
              color: on
                  ? c.hot1.withValues(alpha: .1)
                  : _hover
                  ? c.ink.withValues(alpha: .045)
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                if (on)
                  Positioned(
                    left: -11,
                    child: Container(
                      width: 2,
                      height: 17,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(2),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [c.hot2, c.hot1],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: c.hot1.withValues(alpha: .9),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Opacity(
                      opacity: on ? 1 : .8,
                      child: EvIcon(
                        widget.icon,
                        size: 15,
                        color: on ? c.hot2 : (_hover ? c.ink : c.ink3),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: ev.text.body.copyWith(
                          fontSize: 13,
                          color: on || _hover ? c.ink : c.ink3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Заголовок раздела настроек: крупно, лёгким начертанием, линия
/// и «Сбросить», если есть что сбрасывать.
class EvSettingsHeader extends StatelessWidget {
  const EvSettingsHeader(this.title, {super.key, this.onReset});

  final String title;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final size = (MediaQuery.sizeOf(context).width * .024).clamp(20.0, 28.0);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          title,
          style: ev.text.display(size).copyWith(letterSpacing: size * -.025),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c.line, c.line.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
        if (onReset != null) ...[
          const SizedBox(width: 14),
          EvMiniButton(label: 'Сбросить', onPressed: onReset),
        ],
      ],
    );
  }
}
