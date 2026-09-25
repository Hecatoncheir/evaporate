import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../glass/ev_droplet.dart';
import '../glass/ev_glass.dart';
import '../widgets/ev_focusable.dart';
import '../widgets/ev_icon.dart';
import 'ev_section.dart';

/// Боковой рейл: знак, четыре основных раздела, друзья и аватар.
///
/// Полоса шириной 76 на всю высоту окна — матовое стекло, как в прототипе:
/// сквозь него видно, как поднимается пар, а с экраном она стыкуется одной
/// светящейся кромкой справа. Кнопки стоят колонкой шириной [slabWidth]
/// с полем [inset]. Выбранный раздел помечен каплей стекла, которая
/// перетекает к новому разделу, и янтарной чертой у кромки окна — заливкой
/// не помечается ничего: насыщенный объект на экране один, и это не
/// навигация.
class EvRail extends StatelessWidget {
  const EvRail({
    super.key,
    required this.current,
    required this.onSelect,
    required this.initials,
    required this.userName,
    this.friendsOnline,
    this.downloadsActive,
    this.friends = true,
    this.profile = true,
    this.underlay,
  });

  /// Есть ли внизу «Друзья» и аватар профиля. Приложение их прячет:
  /// данных о друзьях и профиле у него нет.
  final bool friends;
  final bool profile;

  /// Слой под кнопками во всю плиту: за него тянут окно.
  final Widget? underlay;

  final EvSection current;
  final ValueChanged<EvSection> onSelect;
  final String initials;
  final String userName;

  /// Числа в подсказках. `null` — подсказка без числа: рейл не выдумывает
  /// показатели, которых ему не передали.
  final int? friendsOnline;
  final int? downloadsActive;

  /// Поле вокруг колонки кнопок. Нижняя панель узкого окна отступает
  /// от его кромок на столько же.
  static const inset = 8.0;

  /// Ширина колонки кнопок.
  static const slabWidth = EvSpace.railWidth - inset * 2;

  static const _padTop = 10.0;
  static const _padBottom = 6.0;
  static const _markSize = 36.0;
  static const _markGap = 16.0;
  static const itemHeight = 44.0;
  static const itemWidth = 48.0;
  static const _itemGap = 4.0;
  static const avatarSize = 38.0;
  static const _avatarGap = 8.0;

  /// Верх кнопки основного раздела по её номеру.
  static double itemTop(int index) =>
      _padTop + _markSize + _markGap + index * (itemHeight + _itemGap);

  /// Верх кнопки «Друзья» на плите высотой [height].
  static double friendsTop(double height) =>
      height - _padBottom - avatarSize - _avatarGap - itemHeight;

  static double avatarTop(double height) => height - _padBottom - avatarSize;

  /// Куда встаёт капля: она всегда размером с кнопку и центрируется
  /// на выбранном, даже если это аватар.
  static Rect dropletRect(EvSection section, double height) {
    final center = switch (section) {
      EvSection.profile => avatarTop(height) + avatarSize / 2,
      EvSection.friends => friendsTop(height) + itemHeight / 2,
      _ => itemTop(EvSection.primary.indexOf(section)) + itemHeight / 2,
    };
    return Rect.fromLTWH(
      (slabWidth - itemWidth) / 2,
      center - itemHeight / 2,
      itemWidth,
      itemHeight,
    );
  }

  String _tip(L l, EvSection s) => switch (s) {
    EvSection.downloads when downloadsActive != null =>
      '${s.labelOf(l)} · $downloadsActive',
    EvSection.friends when friendsOnline != null =>
      '${s.labelOf(l)} · ${l.evFriendsOnline(friendsOnline!)}',
    _ => s.labelOf(l),
  };

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final l = L.of(context);
    return SizedBox(
      width: EvSpace.railWidth,
      child: EvGlass(
        grouped: true,
        borderRadius: BorderRadius.zero,
        // Кромка только на стыке с экраном: сверху, слева и снизу —
        // край окна.
        rim: const {AxisDirection.right},
        padding: const EdgeInsets.all(inset),
        child: LayoutBuilder(
          builder: (context, box) {
            final height = box.maxHeight;
            return Stack(
              // черта выбранного раздела выходит на поле, к краю окна
              clipBehavior: Clip.none,
              children: [
                if (underlay case final grip?) Positioned.fill(child: grip),
                EvDroplet(
                  rect: dropletRect(current, height),
                  radius: ev.radii.b2,
                ),
                Positioned(
                  top: _padTop,
                  left: (slabWidth - _markSize) / 2,
                  // Знак — не орган управления: за него тянут окно.
                  child: IgnorePointer(
                    child: DecoratedBox(
                      // свечение повторяет плитку знака: rx 14 на сетке 48
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          _markSize * 14 / 48,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ev.colors.hot1.withValues(alpha: 0.35),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: const EvMark(size: _markSize),
                    ),
                  ),
                ),
                for (final (i, s) in EvSection.primary.indexed)
                  Positioned(
                    top: itemTop(i),
                    left: 0,
                    child: EvRailItem(
                      key: ValueKey('rail-${s.name}'),
                      section: s,
                      tooltip: _tip(l, s),
                      active: s == current,
                      onTap: () => onSelect(s),
                      badge: s == EvSection.downloads ? downloadsActive : null,
                    ),
                  ),
                if (friends)
                  Positioned(
                    top: friendsTop(height),
                    left: 0,
                    child: EvRailItem(
                      section: EvSection.friends,
                      tooltip: _tip(l, EvSection.friends),
                      active: current == EvSection.friends,
                      onTap: () => onSelect(EvSection.friends),
                    ),
                  ),
                if (profile)
                  Positioned(
                    top: avatarTop(height),
                    left: (slabWidth - avatarSize) / 2,
                    child: EvAvatar(
                      initials: initials,
                      label: l.evProfileOf(userName),
                      active: current == EvSection.profile,
                      onTap: () => onSelect(EvSection.profile),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Кнопка рейла 48 × 44 в колонке шириной 60: черта активного раздела
/// живёт снаружи кнопки, у края окна.
class EvRailItem extends StatefulWidget {
  const EvRailItem({
    super.key,
    required this.section,
    required this.tooltip,
    required this.active,
    required this.onTap,
    this.width = EvRail.slabWidth,
    this.badge,
  });

  /// Число на кнопке: сколько задач в работе. `null` или ноль — без числа.
  final int? badge;

  final EvSection section;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;
  final double width;

  @override
  State<EvRailItem> createState() => _EvRailItemState();
}

class _EvRailItemState extends State<EvRailItem> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final lit = widget.active || _hover || _focus;
    return SizedBox(
      width: widget.width,
      height: EvRail.itemHeight,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // черта у края окна — за полем колонки, как `left:-14px` в прототипе
          Positioned(
            left: -EvRail.inset,
            child: AnimatedContainer(
              duration: EvMotion.fast,
              curve: EvMotion.ease,
              width: 3,
              height: widget.active ? 22 : 0,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(3),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [c.hot2, c.hot1],
                ),
                boxShadow: [
                  BoxShadow(
                    color: c.hot1.withValues(alpha: 0.9),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
          ),
          Semantics(
            button: true,
            selected: widget.active,
            label: widget.section.labelOf(L.of(context)),
            child: _SideTooltip(
              message: widget.tooltip,
              visible: _hover || _focus,
              child: MouseRegion(
                onEnter: (_) => setState(() => _hover = true),
                onExit: (_) => setState(() => _hover = false),
                child: EvFocusable(
                  onActivate: widget.onTap,
                  radius: ev.radii.r2,
                  onFocusHighlight: (v) => setState(() => _focus = v),
                  child: AnimatedContainer(
                    duration: EvMotion.fast,
                    curve: EvMotion.ease,
                    width: EvRail.itemWidth,
                    height: EvRail.itemHeight,
                    decoration: BoxDecoration(
                      borderRadius: ev.radii.b2,
                      // Выбранное помечает капля стекла под кнопкой,
                      // наведение — светлая плёнка.
                      color: _hover && !widget.active
                          ? c.ink.withValues(alpha: 0.045)
                          : null,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        EvIcon(
                          widget.section.icon,
                          size: 21,
                          color: lit ? c.ink : c.ink3,
                        ),
                        if (widget.badge case final n? when n > 0)
                          Positioned(top: 4, right: 4, child: _Badge(n)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Аватар пользователя. Скругление берётся из потолка радиуса, но не больше
/// половины стороны — при полном радиусе это круг, при 8 px — плитка.
class EvAvatar extends StatefulWidget {
  const EvAvatar({
    super.key,
    required this.initials,
    required this.label,
    required this.active,
    required this.onTap,
    this.size = EvRail.avatarSize,
    this.showTooltip = true,
  });

  final String initials;

  /// Подпись для чтения с экрана и текст подсказки.
  final String label;

  final bool active;
  final VoidCallback onTap;
  final double size;

  /// В нижней панели узкого окна подсказке некуда выйти — там её нет.
  final bool showTooltip;

  @override
  State<EvAvatar> createState() => _EvAvatarState();
}

class _EvAvatarState extends State<EvAvatar> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final r = math.min(ev.radii.pill, widget.size / 2);
    Widget avatar = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: EvFocusable(
        onActivate: widget.onTap,
        radius: r,
        onFocusHighlight: (v) => setState(() => _focus = v),
        child: AnimatedContainer(
          duration: EvMotion.fast,
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r),
            gradient: SweepGradient(
              startAngle: 200 * math.pi / 180,
              endAngle: (200 + 360) * math.pi / 180,
              colors: [c.hot2, c.hot1, c.arc, c.hot2],
            ),
            border: Border.all(
              color: widget.active
                  ? c.hot2
                  : c.ink.withValues(alpha: _hover ? 0.32 : 0.14),
              width: widget.active ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: c.hot1.withValues(alpha: widget.active ? 0.55 : 0.35),
                blurRadius: widget.active ? 22 : 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ExcludeSemantics(
            child: Text(
              widget.initials,
              style: ev.text.dsp(
                ev.text.big(widget.size * 0.34),
                weight: FontWeight.w600,
                color: const Color(0xFF0B0B10),
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
    if (widget.showTooltip) {
      avatar = _SideTooltip(
        message: widget.label,
        visible: _hover || _focus,
        child: avatar,
      );
    }
    return Semantics(
      button: true,
      selected: widget.active,
      label: widget.label,
      child: avatar,
    );
  }
}

/// Подсказка справа от кнопки. Штатный Tooltip умеет только сверху и снизу,
/// а у бокового рейла подсказка должна выходить в сторону контента.
///
/// Слой подсказки подключён всё время, а видимость — это прозрачность:
/// так подсказка и появляется, и гаснет плавно (180 мс, как в прототипе),
/// а контроллер слоя не приходится дёргать посреди сборки.
class _SideTooltip extends StatefulWidget {
  const _SideTooltip({
    required this.message,
    required this.visible,
    required this.child,
  });

  final String message;
  final bool visible;
  final Widget child;

  @override
  State<_SideTooltip> createState() => _SideTooltipState();
}

class _SideTooltipState extends State<_SideTooltip> {
  final _link = LayerLink();
  final _portal = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    // Портал ещё не подключён: вызов только запоминает, что слой нужен.
    _portal.show();
  }

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) => Positioned(
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: Alignment.centerRight,
            followerAnchor: Alignment.centerLeft,
            offset: const Offset(10, 0),
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: AnimatedOpacity(
                  opacity: widget.visible ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: EvGlass(
                    style: EvGlassStyle.raised,
                    borderRadius: ev.radii.b1,
                    shadows: ev.shadowRest,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Text(
                      widget.message,
                      style: ev.text.bodySmall.copyWith(
                        color: ev.colors.ink2,
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

/// Нижняя панель навигации для узких окон: плита стекла, на которой
/// капля отмечает выбранный раздел.
class EvBottomNav extends StatelessWidget {
  const EvBottomNav({
    super.key,
    required this.current,
    required this.onSelect,
    required this.initials,
    this.sections = EvSection.values,
  });

  final EvSection current;
  final ValueChanged<EvSection> onSelect;
  final String initials;

  /// Разделы окна: без «Друзей» и «Профиля» их ячеек здесь нет.
  final List<EvSection> sections;

  static const _itemWidth = 48.0;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final l = L.of(context);
    final slots = [
      for (final s in [...EvSection.primary, EvSection.friends])
        if (sections.contains(s)) s,
    ];
    final avatar = sections.contains(EvSection.profile);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        EvRail.inset,
        0,
        EvRail.inset,
        EvRail.inset,
      ),
      child: EvGlass(
        grouped: true,
        borderRadius: ev.radii.b5,
        shadows: ev.shadowRest,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: SizedBox(
          height: EvSpace.bottomNavHeight - EvRail.inset,
          child: LayoutBuilder(
            builder: (context, box) {
              // spaceAround: у каждой ячейки свой равный кусок ширины,
              // и капля встаёт по центру его.
              final slot = box.maxWidth / (slots.length + (avatar ? 1 : 0));
              final index = slots.indexOf(current);
              final center = slot * ((index < 0 ? slots.length : index) + 0.5);
              return Stack(
                children: [
                  EvDroplet(
                    rect: Rect.fromCenter(
                      center: Offset(center, box.maxHeight / 2),
                      width: _itemWidth,
                      height: box.maxHeight - 10,
                    ),
                    radius: ev.radii.b2,
                    duration: EvMotion.popover,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      for (final s in slots)
                        Semantics(
                          button: true,
                          selected: s == current,
                          label: s.labelOf(l),
                          child: EvFocusable(
                            key: ValueKey('rail-${s.name}'),
                            onActivate: () => onSelect(s),
                            radius: ev.radii.r2,
                            child: SizedBox(
                              width: _itemWidth,
                              height: box.maxHeight,
                              child: Center(
                                child: EvIcon(
                                  s.icon,
                                  size: 21,
                                  color: s == current ? c.ink : c.ink3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (avatar)
                        EvAvatar(
                          initials: initials,
                          label: EvSection.profile.labelOf(l),
                          active: current == EvSection.profile,
                          onTap: () => onSelect(EvSection.profile),
                          size: 32,
                          showTooltip: false,
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Число задач на кнопке «Загрузки»: горячая плашка — насыщенный цвет
/// только у того, что идёт сейчас.
class _Badge extends StatelessWidget {
  const _Badge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minWidth: 15),
          height: 15,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.hot1,
            borderRadius: BorderRadius.circular(7.5),
            boxShadow: ev.glow(c.hot1, opacity: 0.5, blur: 10),
          ),
          child: Text(
            count > 99 ? '99+' : '$count',
            style: ev.text.data.copyWith(
              color: const Color(0xFF170800),
              fontSize: 9.5,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
