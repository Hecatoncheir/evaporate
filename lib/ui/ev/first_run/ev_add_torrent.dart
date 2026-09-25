import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../art/ev_art.dart';
import '../data/game_facts.dart';
import '../data/sample_data.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../sheet/ev_part_row.dart';
import '../widgets/ev_controls.dart';
import '../widgets/ev_icon.dart';
import '../widgets/ev_play_button.dart';
import '../widgets/ev_surfaces.dart';

/// Магнит-ссылка первой раздачи и её хеш: по хешу раздачу можно сверить.
const evFirstMagnet =
    'magnet:?xt=urn:btih:9f2c4d18ab77e0c35b1f6ea2c90d84b3ff17a41b'
    '&dn=ashen-verge-2.4.1';

/// Диалог «Добавить раздачу» — единственное место, где человек выбирает
/// файлы. Маршрут отдаёт, сколько выбрано, ГБ; `null` — передумал.
///
/// Отдаётся маршрут, а не `Future`: сценарий первого запуска закрывает
/// диалог сам, когда шаг листают стрелкой.
Route<double> evAddTorrentRoute({
  required SampleGame game,
  required double freeGb,
  required String folder,
}) => _AddRoute(game: game, freeGb: freeGb, folder: folder);

class _AddRoute extends PopupRoute<double> {
  _AddRoute({required this.game, required this.freeGb, required this.folder});

  final SampleGame game;
  final double freeGb;
  final String folder;

  @override
  Color? get barrierColor => const Color.fromRGBO(4, 4, 8, .74);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Закрыть';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 380);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => EvAddTorrent(game: game, freeGb: freeGb, folder: folder);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final t = CurvedAnimation(parent: animation, curve: EvMotion.easeOut);
    // Фон под диалогом размыт — `backdrop-filter: blur(16px)`.
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 16 * t.value, sigmaY: 16 * t.value),
      child: FadeTransition(
        opacity: t,
        child: AnimatedBuilder(
          animation: t,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, 14 * (1 - t.value)),
            child: Transform.scale(scale: .985 + .015 * t.value, child: child),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Сам диалог: что внутри раздачи, что скачать и куда. Сумма и остаток
/// на диске пересчитываются с каждой галочкой.
class EvAddTorrent extends StatefulWidget {
  const EvAddTorrent({
    super.key,
    required this.game,
    required this.freeGb,
    required this.folder,
  });

  final SampleGame game;
  final double freeGb;

  /// Папка, куда ляжет игра.
  final String folder;

  static const width = 660.0;

  @override
  State<EvAddTorrent> createState() => _EvAddTorrentState();
}

class _EvAddTorrentState extends State<EvAddTorrent> {
  late final _facts = EvGameFacts.of(widget.game);

  // Предлагается то, что карточка игры держит на диске.
  late final Set<EvGamePart> _on = {
    for (final p in _facts.parts)
      if (p.onDisk) p,
  };

  double get _sum =>
      _facts.parts.where(_on.contains).fold(0, (s, p) => s + p.size);

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final g = widget.game;
    final words = g.title.split(' ');
    final title = ev.text.display(22).copyWith(height: 1.05);
    final sum = formatGb(_sum);
    final left = (widget.freeGb - _sum).round();

    Widget pick(String label, {String? value}) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            label.toUpperCase(),
            style: ev.text.data.copyWith(
              fontSize: 10,
              letterSpacing: 1.8,
              color: c.ink4,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [c.lineSoft, c.lineSoft.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: 10),
            Text(value, style: ev.text.data.copyWith(color: c.hot2)),
          ],
        ],
      ),
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: EvAddTorrent.width),
          child: Material(
            type: MaterialType.transparency,
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: 'Добавить раздачу',
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: ev.radii.b4,
                  border: Border.all(color: c.line),
                  color: c.surface,
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, .8),
                      blurRadius: 110,
                      offset: Offset(0, 40),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: ev.radii.b4,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Head(onClose: () => Navigator.of(context).pop()),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 76,
                                    height: 76 * 4 / 3,
                                    decoration: BoxDecoration(
                                      borderRadius: ev.radii.b4,
                                      border: Border.all(color: c.line),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: ev.radii.b4,
                                      child: EvCover(
                                        palette: g.palette,
                                        seed: g.seed,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text.rich(
                                          TextSpan(
                                            children: [
                                              TextSpan(
                                                text:
                                                    '${words.take(words.length - 1).join(' ')} ',
                                              ),
                                              TextSpan(
                                                text: words.last,
                                                style: ev.text.dsp(
                                                  title,
                                                  weight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                          style: title,
                                        ),
                                        const SizedBox(height: 7),
                                        Text(
                                          evFirstMagnet,
                                          style: ev.text.data.copyWith(
                                            fontSize: 10.5,
                                            color: c.ink4,
                                          ),
                                        ),
                                        const SizedBox(height: 11),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            const EvChip(
                                              '27 сидов · 31 пир',
                                              hot: true,
                                            ),
                                            EvChip(g.version),
                                            const EvChip('RU + ENG'),
                                            const EvChip('118 421 файл'),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              pick('Что скачать', value: sum),
                              for (final part in _facts.parts)
                                EvPartRow(
                                  part: part,
                                  on: _on.contains(part),
                                  onToggle: part.required
                                      ? null
                                      : () => setState(
                                          () => _on.contains(part)
                                              ? _on.remove(part)
                                              : _on.add(part),
                                        ),
                                ),
                              pick('Куда'),
                              _Destination(
                                folder: widget.folder,
                                free: widget.freeGb.round(),
                                left: left,
                              ),
                            ],
                          ),
                        ),
                      ),
                      _Foot(
                        sum: sum,
                        onCancel: () => Navigator.of(context).pop(),
                        onGo: () => Navigator.of(context).pop(_sum),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 11, 12, 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.lineSoft)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'ДОБАВИТЬ РАЗДАЧУ',
              style: ev.text.dsp(
                ev.text.section,
                size: 12,
                weight: FontWeight.w600,
                letterSpacing: 12 * .18,
              ),
            ),
          ),
          EvIconButton(
            icon: EvIcons.close,
            label: 'Закрыть',
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.folder,
    required this.free,
    required this.left,
  });

  final String folder;
  final int free;
  final int left;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final small = ev.text.data.copyWith(fontSize: 10.5, color: c.ink4);
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: ev.radii.b2,
              border: Border.all(color: c.lineSoft),
              color: c.ink.withValues(alpha: .022),
            ),
            child: Row(
              children: [
                EvIcon(EvIcons.drive, size: 15, color: c.ink3),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    folder,
                    overflow: TextOverflow.ellipsis,
                    style: ev.text.data.copyWith(fontSize: 12, color: c.ink2),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        const EvMiniButton(
          label: 'Изменить',
          icon: EvIcons.folder,
          onPressed: null,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('свободно $free ГБ', style: small),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'останется '),
                  TextSpan(
                    text: '$left ГБ',
                    style: small.copyWith(
                      color: left < 0 ? EvColors.bad : EvColors.ok,
                    ),
                  ),
                ],
              ),
              style: small,
            ),
          ],
        ),
      ],
    );
  }
}

class _Foot extends StatelessWidget {
  const _Foot({required this.sum, required this.onCancel, required this.onGo});

  final String sum;
  final VoidCallback onCancel;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.lineSoft)),
        color: c.ink.withValues(alpha: .015),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'btih 9f2c4d18…ff17a41b · проверено',
              style: ev.text.data.copyWith(fontSize: 10.5, color: c.ink4),
            ),
          ),
          const SizedBox(width: 12),
          EvMiniButton(label: 'Отмена', onPressed: onCancel),
          const SizedBox(width: 12),
          EvPlayButton(
            label: 'Скачать',
            icon: EvIcons.download,
            caption: sum.toUpperCase(),
            height: 44,
            requireHold: false,
            onLaunch: onGo,
          ),
        ],
      ),
    );
  }
}
