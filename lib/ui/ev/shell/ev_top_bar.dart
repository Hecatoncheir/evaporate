import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../glass/ev_glass.dart';
import '../widgets/ev_focusable.dart';
import '../widgets/ev_icon.dart';

/// Верхняя полоса: хлебная крошка слева, поиск и живые показатели справа.
///
/// Высота 58. Полоса сделана из матового стекла и лежит **поверх** экрана:
/// содержимое уходит под неё при прокрутке, и видно, что оно там есть, —
/// размытое и притенённое.
class EvTopBar extends StatelessWidget {
  const EvTopBar({
    super.key,
    required this.section,
    this.onSearch,
    this.trailing = const [],
    this.tools,
    this.end,
    this.underlay,
  });

  /// Текущий раздел — вторая часть крошки.
  final String section;

  /// То, что стоит сразу за крошкой: переключатель видов библиотеки.
  final Widget? tools;

  /// С какой ширины окна за крошкой хватает места переключателю видов
  /// вместе с поиском и плашками.
  static const toolsFrom = 1080.0;

  /// С какой ширины окна рядом с поиском и клавишами окна помещаются
  /// показатели. Уже — они уходят: скорости обмена и движок видны и в
  /// строке подсказок (в узком окне её нет — там число задач на нижней
  /// панели), а клавиши окна без замены не обойтись.
  static const statusFrom = 1000.0;

  final VoidCallback? onSearch;

  /// Показатели: скорость, состояние движка.
  final List<Widget> trailing;

  /// Последнее справа — клавиши окна. В отличие от [trailing], не прячется
  /// в узком окне: без них окно без рамки не свернуть и не закрыть.
  final Widget? end;

  /// Слой под содержимым во всю полосу: за него тянут окно. Надписи
  /// крошки нажатий не забирают — окно тянется и за собственное имя.
  final Widget? underlay;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final gutter = EvSpace.gutterFor(MediaQuery.sizeOf(context));
    return EvGlass(
      grouped: true,
      borderRadius: BorderRadius.zero,
      // Стык с экраном — снизу; слева полоса упирается в кромку рейла.
      rim: const {AxisDirection.down},
      child: SizedBox(
        height: EvSpace.topBarHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ?underlay,
            Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: _row(ev, c),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(EvTheme ev, EvColors c) => Row(
    children: [
      _Inert(
        child: Text(
          'EVAPORATE',
          style: ev.text.section.copyWith(fontSize: 12, letterSpacing: 1.9),
        ),
      ),
      _Inert(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: Text('/', style: ev.text.bodySmall.copyWith(color: c.ink4)),
        ),
      ),
      // Крошка забирает всё свободное место, поэтому поиск и показатели
      // прижаты к правому полю. Flexible рядом со Spacer получил бы
      // половину места и не отдал неиспользованное — правая группа
      // не доезжала бы до края.
      Expanded(
        child: Row(
          children: [
            Flexible(
              child: _Inert(
                child: AnimatedSwitcher(
                  duration: EvMotion.fast,
                  // старая и новая подписи разной длины: обе прижаты
                  // влево, иначе короткая на миг съезжает к середине
                  // длинной
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...previous, ?current],
                  ),
                  child: Text(
                    section,
                    key: ValueKey(section),
                    overflow: TextOverflow.ellipsis,
                    style: ev.text.bodySmall.copyWith(
                      color: c.ink2,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            ),
            if (tools != null) ...[const SizedBox(width: 14), tools!],
          ],
        ),
      ),
      const SizedBox(width: EvSpace.l),
      _SearchButton(onTap: onSearch),
      for (final w in trailing) ...[const SizedBox(width: 10), w],
      if (end != null) ...[const SizedBox(width: 12), end!],
    ],
  );
}

/// Надпись крошки: окно тянется и за неё, а диктору она не читается —
/// раздел он слышит выбранной клавишей рейла и заголовком страницы, а
/// «EVAPORATE, косая черта» — шум.
class _Inert extends StatelessWidget {
  const _Inert({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(child: IgnorePointer(child: child));
}

class _SearchButton extends StatefulWidget {
  const _SearchButton({this.onTap});

  final VoidCallback? onTap;

  @override
  State<_SearchButton> createState() => _SearchButtonState();
}

class _SearchButtonState extends State<_SearchButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final ink = _hover ? c.ink2 : c.ink3;
    final l = L.of(context);
    return Semantics(
      button: true,
      label: l.evSearchKeyLabel,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() {
          _hover = false;
          _pressed = false;
        }),
        child: Listener(
          onPointerDown: (_) => setState(() => _pressed = true),
          onPointerUp: (_) => setState(() => _pressed = false),
          onPointerCancel: (_) => setState(() => _pressed = false),
          child: EvFocusable(
            onActivate: widget.onTap,
            radius: ev.radii.r2,
            child: EvGlass(
              // Кнопка лежит на стекле полосы — читать фон второй раз незачем.
              style: EvGlassStyle.chip,
              backdrop: false,
              interactive: true,
              pressed: _pressed,
              borderRadius: ev.radii.b2,
              tint: c.ink.withValues(alpha: _hover ? 0.08 : 0.04),
              padding: const EdgeInsets.only(left: 11, right: 10),
              child: SizedBox(
                height: 34,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EvIcon(EvIcons.search, size: 15, color: ink),
                    const SizedBox(width: 9),
                    Text(
                      l.hintSearch,
                      style: ev.text.bodySmall.copyWith(color: ink),
                    ),
                    const SizedBox(width: 9),
                    const EvKey('/', dense: true),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Клавиша: моноширинная подпись на кусочке стекла. Общая для топбара
/// и строки подсказок, чтобы клавиши выглядели одинаково везде.
class EvKey extends StatelessWidget {
  const EvKey(this.label, {super.key, this.dense = false});

  final String label;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return EvGlass(
      style: EvGlassStyle.chip,
      backdrop: false,
      borderRadius: ev.radii.b1,
      tint: c.ink.withValues(alpha: dense ? 0.08 : 0.07),
      padding: EdgeInsets.symmetric(horizontal: dense ? 5 : 6, vertical: 2),
      child: Text(
        label,
        style: ev.text.data.copyWith(
          color: c.ink3,
          fontSize: 10.5,
          height: 1.2,
        ),
      ),
    );
  }
}
