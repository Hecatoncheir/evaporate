import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../glass/ev_glass.dart';
import '../library/library_layout.dart';
import '../shell/ev_top_bar.dart' show EvKey;
import '../widgets/ev_controls.dart';
import '../widgets/ev_focusable.dart';
import '../widgets/ev_icon.dart';
import '../widgets/ev_play_button.dart';
import '../widgets/ev_surfaces.dart';

/// Пустая библиотека. Не извинение, а точка входа: знак светится, два
/// пути внутрь и зона, куда бросить раздачу, — все три ведут к добавлению.
class EvLibraryEmpty extends StatelessWidget {
  const EvLibraryEmpty({super.key, this.onScan, this.onMagnet, this.onDrop});

  final VoidCallback? onScan;
  final VoidCallback? onMagnet;

  /// Зона перетаскивания. Нажатие ведёт туда же, куда бросок.
  final VoidCallback? onDrop;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final window = MediaQuery.sizeOf(context);
    final size = (window.width * .04).clamp(24.0, 40.0);
    final title = ev.text.display(size).copyWith(height: 1.02);
    final text = ev.text.body.copyWith(fontSize: 14.5, color: c.ink2);
    final hint = ev.text.data.copyWith(fontSize: 10.5, color: c.ink4);
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: (window.height * .07).clamp(28.0, 70.0),
      ),
      child: Column(
        children: [
          const _GlowingMark(),
          const SizedBox(height: 20),
          // Две строки, как заголовок героя. В прототипе вторая часть была
          // просто жирной и приклеивалась к первой: «игрыпока что».
          Semantics(
            header: true,
            label: 'Ни одной игры пока что',
            excludeSemantics: true,
            child: Column(
              children: [
                Text('Ни одной игры', style: title),
                Text(
                  'пока что',
                  style: ev.text.dsp(title, weight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: evCharWidth(text) * 48),
            child: Text(
              'Evaporate ищет игры двумя путями: подхватывает уже '
              'установленные с диска или скачивает новые через встроенный '
              'движок. Начните с любого.',
              textAlign: TextAlign.center,
              style: text,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 11,
            runSpacing: 11,
            alignment: WrapAlignment.center,
            children: [
              EvPlayButton(
                label: 'Просканировать диск',
                icon: EvIcons.folder,
                height: 52,
                requireHold: false,
                caption: '',
                onLaunch: onScan,
              ),
              EvGhostButton(
                label: 'Вставить magnet-ссылку',
                icon: EvIcons.magnet,
                height: 52,
                onPressed: onMagnet,
              ),
            ],
          ),
          const SizedBox(height: 26),
          _DropZone(onTap: onDrop),
          const SizedBox(height: 24),
          Wrap(
            spacing: 22,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final (k, label) in const [
                ('Ctrl+O', 'Открыть файл'),
                ('Ctrl+V', 'Вставить ссылку'),
                ('/', 'Поиск по каталогу'),
              ])
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EvKey(k),
                    const SizedBox(width: 7),
                    Text(label, style: hint),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Знак в тёплом ореоле, который медленно дышит — пустой экран живой.
class _GlowingMark extends StatefulWidget {
  const _GlowingMark();

  @override
  State<_GlowingMark> createState() => _GlowingMarkState();
}

class _GlowingMarkState extends State<_GlowingMark>
    with SingleTickerProviderStateMixin {
  late final _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _breath.stop();
    } else if (!_breath.isAnimating) {
      _breath.repeat();
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ev.colors;
    return SizedBox.square(
      dimension: 104,
      child: AnimatedBuilder(
        animation: _breath,
        builder: (context, child) {
          // breathe: к середине ореол ярче и на 5 % шире.
          final t = math.sin(_breath.value * math.pi);
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Transform.scale(
                scale: 1 + .05 * t,
                child: Opacity(
                  opacity: .7 + .3 * t,
                  child: Container(
                    width: 104 * 1.28,
                    height: 104 * 1.28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          c.hot1.withValues(alpha: .22),
                          c.hot1.withValues(alpha: 0),
                        ],
                        stops: const [0, .68],
                      ),
                    ),
                  ),
                ),
              ),
              child!,
            ],
          );
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: c.hot1.withValues(alpha: .6), blurRadius: 26),
            ],
          ),
          child: const EvMark(size: 64),
        ),
      ),
    );
  }
}

class _DropZone extends StatefulWidget {
  const _DropZone({this.onTap});

  final VoidCallback? onTap;

  @override
  State<_DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<_DropZone> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final color = _hover ? c.ink2 : c.ink3;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: EvFocusable(
          onActivate: widget.onTap,
          radius: ev.radii.r4,
          child: CustomPaint(
            painter: EvDashedBorder(
              color: _hover ? c.hot1.withValues(alpha: .5) : c.line,
              radius: ev.radii.r4,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: ev.radii.b4,
                color: _hover ? c.hot1.withValues(alpha: .05) : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Opacity(
                    opacity: .7,
                    child: EvIcon(EvIcons.download, size: 17, color: color),
                  ),
                  const SizedBox(width: 14),
                  Flexible(
                    child: Text(
                      'Перетащите сюда .torrent или папку с игрой',
                      style: ev.text.data.copyWith(
                        fontSize: 11.5,
                        letterSpacing: .7,
                        color: color,
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

/// Чтение каталога: скелет героя и полки с бликом, который бежит поперёк.
/// Блик стоит, если в системе уменьшено движение.
class EvLibrarySkeleton extends StatefulWidget {
  const EvLibrarySkeleton({super.key, required this.layout});

  final EvLibraryLayout layout;

  @override
  State<EvLibrarySkeleton> createState() => _EvLibrarySkeletonState();
}

class _EvLibrarySkeletonState extends State<EvLibrarySkeleton>
    with SingleTickerProviderStateMixin {
  late final _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _shimmer.stop();
    } else if (!_shimmer.isAnimating) {
      _shimmer.repeat();
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  Widget _bone(double? width, double height, BorderRadius radius) =>
      AnimatedBuilder(
        animation: _shimmer,
        builder: (context, _) {
          final c = context.ev.colors;
          // translateX(-100% → 160%): блик шириной в элемент.
          final x = -1 + _shimmer.value * 2.6;
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: radius,
              color: c.raised,
              gradient: LinearGradient(
                begin: Alignment(-1 + x * 2, -.2),
                end: Alignment(1 + x * 2, .2),
                colors: [
                  c.raised,
                  Color.alphaBlend(c.ink.withValues(alpha: .055), c.raised),
                  c.raised,
                ],
                stops: const [.2, .45, .7],
              ),
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final l = widget.layout;
    final h = MediaQuery.sizeOf(context).height;
    final card = l.cardWidth;
    return Semantics(
      label: 'Читаем каталог',
      child: Padding(
        padding: EdgeInsets.only(top: l.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _bone(null, (h * .46).clamp(300.0, 460.0), ev.radii.b5),
            const SizedBox(height: 30),
            ClipRect(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < 6; i++) ...[
                      if (i > 0) const SizedBox(width: 16),
                      SizedBox(
                        width: card,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _bone(card, card * 4 / 3, ev.radii.b3),
                            const SizedBox(height: 11),
                            _bone(card * .78, 11, BorderRadius.circular(5)),
                            const SizedBox(height: 7),
                            _bone(card * .48, 8, BorderRadius.circular(4)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Полоса сценария внизу окна: номер шага, что происходит и листание.
/// `←` `→` листают, крестик выходит из сценария.
class EvFlowBar extends StatelessWidget {
  const EvFlowBar({
    super.key,
    required this.index,
    required this.count,
    required this.title,
    required this.detail,
    required this.onPrevious,
    required this.onNext,
    required this.onExit,
  });

  final int index;
  final int count;
  final String title;
  final String detail;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onExit;

  static const width = 620.0;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final last = index == count - 1;
    final wide = MediaQuery.sizeOf(context).width >= 560;
    return Semantics(
      liveRegion: true,
      label: 'Шаг ${index + 1} из $count: $title',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: ev.radii.b4,
          boxShadow: [
            const BoxShadow(
              color: Color.fromRGBO(0, 0, 0, .7),
              blurRadius: 64,
              offset: Offset(0, 24),
            ),
            BoxShadow(color: c.hot1.withValues(alpha: .12), blurRadius: 40),
          ],
        ),
        child: EvGlass(
          style: EvGlassStyle.raised,
          borderRadius: ev.radii.b4,
          tint: const Color.fromRGBO(14, 15, 22, .94),
          keyLight: c.hot2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 2,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(color: c.ink.withValues(alpha: .07)),
                    ),
                    FractionallySizedBox(
                      widthFactor: (index + 1) / count,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [c.hot1, c.hot2]),
                          boxShadow: [
                            BoxShadow(
                              color: c.hot1.withValues(alpha: .8),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: c.hot1.withValues(alpha: .4)),
                        color: c.hot1.withValues(alpha: .1),
                      ),
                      child: Text(
                        '${index + 1}/$count',
                        style: ev.text.data.copyWith(
                          fontSize: 11,
                          color: c.hot2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ev.text.ui(
                              ev.text.body,
                              size: 13.5,
                              weight: FontWeight.w500,
                              color: c.ink,
                            ),
                          ),
                          if (wide && detail.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              detail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ev.text.data.copyWith(
                                fontSize: 10.5,
                                color: c.ink4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 13),
                    Opacity(
                      opacity: index == 0 ? .35 : 1,
                      // Стрелка назад — та же «вперёд», отражённая.
                      child: Transform.flip(
                        flipX: true,
                        child: EvIconButton(
                          icon: EvIcons.go,
                          label: 'Назад',
                          onPressed: index == 0 ? null : onPrevious,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    EvGhostButton(
                      label: last ? 'Заново' : 'Дальше',
                      icon: last ? EvIcons.retry : EvIcons.go,
                      height: 38,
                      onPressed: onNext,
                    ),
                    const SizedBox(width: 7),
                    EvIconButton(
                      icon: EvIcons.close,
                      label: 'Выйти из сценария',
                      onPressed: onExit,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
