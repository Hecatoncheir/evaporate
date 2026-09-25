import 'package:flutter/widgets.dart';

import '../art/ev_art.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../util/units.dart';
import '../widgets/ev_controls.dart';
import '../widgets/ev_icon.dart';
import '../widgets/ev_surfaces.dart';
import 'download_data.dart';

/// Раздача целиком: обложка, имя с трекера, действия, разбор, приборы,
/// полоса и подпись под ней. Порядок сверху вниз — от «что это» к «как
/// идёт»; разбор встаёт между ними, потому что он объясняет приборы.
class EvTorrentRow extends StatelessWidget {
  const EvTorrentRow({
    super.key,
    required this.torrent,
    this.onPause,
    this.onOpenFolder,
    this.onCancel,
  });

  final EvTorrent torrent;
  final VoidCallback? onPause;
  final VoidCallback? onOpenFolder;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final t = torrent;
    final accent = evToneColor(c, t.tone);
    return Container(
      decoration: BoxDecoration(
        borderRadius: ev.radii.b3,
        border: Border.all(
          color: accent == null ? c.lineSoft : accent.withValues(alpha: .32),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: accent == null || t.tone == EvTorrentTone.idle
              ? [c.ink.withValues(alpha: .026), c.ink.withValues(alpha: .004)]
              : [accent.withValues(alpha: .05), c.ink.withValues(alpha: .004)],
        ),
      ),
      // Прозрачность паузы — на всю строку: она тише остальных, но
      // читается целиком.
      child: Opacity(
        opacity: t.tone == EvTorrentTone.idle ? .86 : 1,
        child: Stack(
          children: [
            if (accent != null)
              Positioned(
                left: 0,
                top: 14,
                bottom: 14,
                width: 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(2),
                    ),
                    boxShadow: t.tone == EvTorrentTone.idle
                        ? null
                        : [BoxShadow(color: accent, blurRadius: 12)],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Head(
                    torrent: t,
                    onPause: onPause,
                    onOpenFolder: onOpenFolder,
                    onCancel: onCancel,
                  ),
                  if (t.alert != null) ...[
                    const SizedBox(height: 12),
                    EvAlertBox(alert: t.alert!),
                  ],
                  const SizedBox(height: 12),
                  _Stats(torrent: t),
                  const SizedBox(height: 12),
                  EvBar(t.progress, tone: t.bar),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${formatGbDot(t.parts.received)} / '
                          '${formatGbDot(t.parts.total)} · ${t.eta}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ev.text.data.copyWith(
                            fontSize: 11,
                            color: c.ink4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${percent(t.progress)}%',
                        style: ev.text.dataStrong.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Цвет причины. `null` — обычная раздача, выделять нечем.
Color? evToneColor(EvColors c, EvTorrentTone tone) => switch (tone) {
  EvTorrentTone.none => null,
  EvTorrentTone.warn => EvColors.warn,
  EvTorrentTone.err => EvColors.bad,
  EvTorrentTone.arc => c.arc,
  EvTorrentTone.idle => c.ink4,
};

/// Гигабайты так, как их пишет раздел: с точкой, в один знак.
String formatGbDot(double value) => '${value.toStringAsFixed(1)} ГБ';

class _Head extends StatelessWidget {
  const _Head({
    required this.torrent,
    this.onPause,
    this.onOpenFolder,
    this.onCancel,
  });

  final EvTorrent torrent;
  final VoidCallback? onPause;
  final VoidCallback? onOpenFolder;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final t = torrent;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.line),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: EvCover(palette: t.game.palette, seed: t.game.seed),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ev.text.ui(ev.text.title, size: 14),
              ),
              const SizedBox(height: 4),
              Text(
                t.path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ev.text.data.copyWith(fontSize: 10.5, color: c.ink4),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Row(
          children: [
            EvIconButton(
              icon: t.paused ? EvIcons.play : EvIcons.pause,
              label: t.paused ? 'Продолжить' : 'Пауза',
              onPressed: onPause,
            ),
            const SizedBox(width: 7),
            EvIconButton(
              icon: EvIcons.folder,
              label: 'Открыть папку',
              accent: EvIconButtonAccent.hot,
              onPressed: onOpenFolder,
            ),
            const SizedBox(width: 7),
            EvIconButton(
              icon: EvIcons.close,
              label: 'Отменить',
              accent: EvIconButtonAccent.danger,
              onPressed: onCancel,
            ),
          ],
        ),
      ],
    );
  }
}

/// Четыре прибора раздачи. Числа моноширинные и всегда на своих местах,
/// чтобы соседние строки читались колонками.
class _Stats extends StatelessWidget {
  const _Stats({required this.torrent});

  final EvTorrent torrent;

  @override
  Widget build(BuildContext context) {
    final t = torrent;
    String rate(int? kb, {int digits = 2}) =>
        kb == null ? '—' : formatRate(kb, digits: digits);
    return Wrap(
      spacing: 18,
      runSpacing: 6,
      children: [
        _Stat(icon: EvIcons.speed, label: 'приём', value: rate(t.downKb)),
        _Stat(icon: EvIcons.seed, label: 'отдача', value: rate(t.upKb)),
        _Stat(
          icon: EvIcons.disk,
          label: 'пик',
          value: rate(t.peakKb, digits: 1),
        ),
        _Stat(
          icon: EvIcons.peers,
          label: 'сиды',
          value: '${t.seeds}',
          label2: ' · пиры ',
          value2: '${t.peers}',
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    this.label2,
    this.value2,
  });

  final String icon;
  final String label;
  final String value;
  final String? label2;
  final String? value2;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final plain = ev.text.data.copyWith(fontSize: 11.5, color: c.ink3);
    final strong = ev.text.mono(plain, weight: FontWeight.w500, color: c.ink2);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(opacity: .8, child: EvIcon(icon, size: 13, color: c.ink3)),
        const SizedBox(width: 7),
        Text.rich(
          TextSpan(
            style: plain,
            children: [
              // Пробел вместо зазора в 7 px: моноширинный знак ровно
              // такой ширины, и числа соседних строк встают колонкой.
              TextSpan(text: '$label '),
              TextSpan(text: value, style: strong),
              if (label2 != null) TextSpan(text: label2),
              if (value2 != null) TextSpan(text: value2, style: strong),
            ],
          ),
        ),
      ],
    );
  }
}

/// Разбор внутри раздачи: знак, причина, объяснение и выход. Сначала
/// сказать, что случилось и почему это не страшно, и только потом — что
/// можно нажать.
class EvAlertBox extends StatelessWidget {
  const EvAlertBox({super.key, required this.alert});

  final EvTorrentAlert alert;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final accent = evToneColor(c, alert.tone);
    final tinted = alert.tone != EvTorrentTone.idle && accent != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: ev.radii.b2,
        border: Border.all(color: c.lineSoft),
        color: c.ink.withValues(alpha: .035),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: tinted ? accent.withValues(alpha: .4) : c.line,
              ),
              color: tinted ? accent.withValues(alpha: .1) : null,
            ),
            child: EvIcon(
              alert.icon,
              size: 14,
              color: tinted ? accent : c.ink3,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title, style: ev.text.ui(ev.text.title, size: 13)),
                const SizedBox(height: 3),
                Text(
                  alert.detail,
                  style: ev.text.body.copyWith(fontSize: 12, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final a in alert.actions)
                  a.primary
                      ? EvGhostButton(
                          label: a.label,
                          icon: a.icon,
                          height: 38,
                          grouped: true,
                          onPressed: () {},
                        )
                      : EvMiniButton(
                          label: a.label,
                          icon: a.icon,
                          onPressed: () {},
                        ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Строка очереди: пунктир вместо рамки — раздача ещё не занимает место.
class EvQueueRow extends StatelessWidget {
  const EvQueueRow({super.key, required this.item, this.onRemove});

  final EvQueued item;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    return CustomPaint(
      painter: EvDashedBorder(color: c.line, radius: ev.radii.r2),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        child: Row(
          children: [
            EvIcon(EvIcons.folder, size: 13, color: c.ink4),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                item.line,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ev.text.data.copyWith(fontSize: 11.5, color: c.ink3),
              ),
            ),
            const SizedBox(width: 11),
            EvIconButton(
              icon: EvIcons.close,
              label: 'Убрать из очереди',
              accent: EvIconButtonAccent.danger,
              size: 22,
              bare: true,
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}
