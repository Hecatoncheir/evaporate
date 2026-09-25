import 'package:flutter/material.dart';

import '../theme.dart';

/// Подсказка справа от клавиши обоймы — под курсором и в фокусе.
///
/// Штатный `Tooltip` выходит только сверху или снизу, а у колонки слева
/// подсказка сверху закрыла бы соседнюю клавишу: ей место сбоку, в сторону
/// содержимого. Фокус нужен наравне с курсором — с геймпада и клавиатуры
/// клавиши обоймы узнаются только по ней.
///
/// Слой подсказки подключён всё время, а видимость — прозрачность: так
/// подсказка и появляется, и гаснет плавно, а слоем не приходится
/// распоряжаться посреди сборки. Облик — тема подсказок приложения.
class RailTooltip extends StatefulWidget {
  const RailTooltip({super.key, required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  State<RailTooltip> createState() => _RailTooltipState();
}

class _RailTooltipState extends State<RailTooltip> {
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  bool _hovered = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    // Портал ещё не подключён: вызов только запоминает, что слой нужен.
    _portal.show();
  }

  @override
  Widget build(BuildContext context) {
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
            offset: const Offset(EvaporateSpacing.cluster, 0),
            child: _Bubble(
              message: widget.message,
              visible: _hovered || _focused,
            ),
          ),
        ),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onFocusChange: (value) => setState(() => _focused = value),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Сама подсказка: подпись на плашке темы подсказок. Нажатий не ловит, а
/// диктору подпись отдаёт клавиша.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.visible});

  final String message;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final tooltip = Theme.of(context).tooltipTheme;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedOpacity(
          key: const ValueKey('rail-tooltip'),
          opacity: visible ? 1 : 0,
          duration: context.motion.fast,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: EvaporateSpacing.gap,
              vertical: EvaporateSpacing.line,
            ),
            decoration: tooltip.decoration,
            child: Text(message, style: tooltip.textStyle),
          ),
        ),
      ),
    );
  }
}
