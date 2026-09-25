import 'package:flutter/widgets.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../widgets/ev_controls.dart';
import '../widgets/ev_icon.dart';
import 'saves_data.dart';

/// Расхождение сохранений: не ошибка, а выбор.
///
/// Поэтому карточка жёлтая, а не красная, обе версии стоят рядом
/// и показывают одни и те же четыре факта, а внизу есть третий выход —
/// оставить обе. Кнопка «Оставить эту» у каждой колонки своя: решение
/// принимается там, где видно, что именно вы оставляете.
class EvConflictCard extends StatelessWidget {
  const EvConflictCard({
    super.key,
    required this.conflict,
    this.onKeep,
    this.onKeepBoth,
  });

  final EvSaveConflict conflict;

  /// Оставить версию с этого устройства (`true`) или со второго.
  final ValueChanged<bool>? onKeep;

  final VoidCallback? onKeepBoth;

  /// Ниже 700 колонки встают друг под друга и разделитель не нужен.
  static const breakpoint = 700.0;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final narrow = MediaQuery.sizeOf(context).width < breakpoint;
    final sides = [
      _Side(side: conflict.mine, pick: true, onKeep: () => onKeep?.call(true)),
      _Side(side: conflict.theirs, onKeep: () => onKeep?.call(false)),
    ];
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: ev.radii.b4,
        border: Border.all(color: EvColors.warn.withValues(alpha: .34)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            EvColors.warn.withValues(alpha: .06),
            c.ink.withValues(alpha: .005),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(conflict: conflict),
          if (narrow)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: sides,
            )
          else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: sides.first),
                  const _Divider(),
                  Expanded(child: sides.last),
                ],
              ),
            ),
          _Footer(note: conflict.note, onKeepBoth: onKeepBoth),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.conflict});

  final EvSaveConflict conflict;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.lineSoft)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: ev.radii.b4,
              border: Border.all(color: EvColors.warn.withValues(alpha: .4)),
              color: EvColors.warn.withValues(alpha: .1),
            ),
            child: const EvIcon(EvIcons.merge, size: 15, color: EvColors.warn),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conflict.title,
                  style: ev.text.ui(ev.text.title, size: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  conflict.detail,
                  style: ev.text.body.copyWith(fontSize: 12, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Вертикальная черта с надписью «против» посередине.
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return SizedBox(
      width: 34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 16,
            bottom: 16,
            width: 1,
            child: ColoredBox(color: c.line),
          ),
          // Слово шире колонки и выходит за неё — так оно закрывает
          // черту собой, а не ломается пополам.
          OverflowBox(
            maxWidth: 90,
            child: Container(
              color: c.surface,
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Text(
                'ПРОТИВ',
                textAlign: TextAlign.center,
                softWrap: false,
                style: ev.text.mono(
                  ev.text.data,
                  size: 9,
                  letterSpacing: 1.26,
                  color: c.ink4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.side, this.pick = false, this.onKeep});

  final EvConflictSide side;

  /// Версия с этого устройства — она подсвечена тёплым.
  final bool pick;

  final VoidCallback? onKeep;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      color: pick ? c.hot1.withValues(alpha: .05) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              EvIcon(side.device.icon, size: 13, color: c.ink3),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  side.device.here
                      ? '${side.device.name} · это устройство'
                      : side.device.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ev.text.data.copyWith(fontSize: 10.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: side.when),
                TextSpan(
                  text: '  ${side.ago} назад',
                  style: ev.text.mono(
                    ev.text.data,
                    size: 11,
                    color: c.ink4,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
            style: ev.text.display(22).copyWith(height: 1.15),
          ),
          const SizedBox(height: 13),
          for (var row = 0; row * 2 < side.facts.length; row++) ...[
            if (row > 0) const SizedBox(height: 9),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _Fact(fact: side.facts[row * 2])),
                const SizedBox(width: 14),
                Expanded(child: _Fact(fact: side.facts[row * 2 + 1])),
              ],
            ),
          ],
          const SizedBox(height: 15),
          EvGhostButton(
            label: 'Оставить эту',
            icon: EvIcons.check,
            height: 38,
            grouped: true,
            onPressed: onKeep,
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.fact});

  final (String, String) fact;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fact.$1.toUpperCase(),
          style: ev.text.mono(ev.text.data, size: 9, letterSpacing: 1.26),
        ),
        const SizedBox(height: 3),
        Text(
          fact.$2,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ev.text.ui(ev.text.title, size: 13, weight: FontWeight.w400),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.note, this.onKeepBoth});

  final String note;
  final VoidCallback? onKeepBoth;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.lineSoft)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          EvMiniButton(
            label: 'Сохранить обе копии',
            icon: EvIcons.saves,
            onPressed: onKeepBoth,
          ),
          Text(
            note,
            style: ev.text.data.copyWith(fontSize: 10.5, color: c.ink4),
          ),
        ],
      ),
    );
  }
}
