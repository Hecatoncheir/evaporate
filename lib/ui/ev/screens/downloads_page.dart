import 'package:flutter/widgets.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../downloads/download_data.dart';
import '../downloads/ev_torrent_row.dart';
import '../downloads/rate_graph.dart';
import '../util/plural.dart';
import '../util/units.dart';
import '../widgets/ev_controls.dart';
import '../widgets/ev_icon.dart';
import '../widgets/ev_surfaces.dart';

/// Загрузки — приборная доска раздачи.
///
/// Сверху два прибора: что происходит сейчас (приём, график за минуту,
/// четыре числа) и из чего это состоит (кольцо частей и активность пиров).
/// Ниже — сами раздачи и очередь. Ни одно число в шапке не написано
/// отдельно от строк: приём, отдача и «активных» складываются из них,
/// поэтому разойтись не могут.
class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key, required this.downloads});

  final EvDownloads downloads;

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage>
    with SingleTickerProviderStateMixin {
  /// Секунда приёма — один отсчёт графика; тепловая карта живёт своим
  /// шагом в 900 мс, как в прототипе.
  static const _second = Duration(seconds: 1);
  static const _heatStep = Duration(milliseconds: 900);

  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(minutes: 1),
    // Приборы идут по настоящим часам: «меньше движения» гасит их
    // совсем, а не ускоряет в двадцать раз.
    animationBehavior: AnimationBehavior.preserve,
  );
  late EvRateSeries _series = EvRateSeries(widget.downloads.downKb / 1000);
  int _ticks = 0;
  int _heat = 0;

  @override
  void initState() {
    super.initState();
    _clock.addListener(_tick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // «Меньше движения» — приборы замирают на первом кадре, как `RM`
    // в прототипе.
    if (MediaQuery.disableAnimationsOf(context)) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      // Часы после остановки идут с нуля — счёт шагов тоже, иначе
      // приборы стояли бы столько же, сколько шли до «меньше движения».
      _ticks = 0;
      _heat = 0;
      _clock.repeat();
    }
  }

  @override
  void didUpdateWidget(DownloadsPage old) {
    super.didUpdateWidget(old);
    // Состояние раздела сменилось — приборы начинают с нового числа,
    // а не дотягивают старую историю.
    if (old.downloads.downKb != widget.downloads.downKb) {
      _series = EvRateSeries(widget.downloads.downKb / 1000);
      _ticks = 0;
    }
  }

  void _tick() {
    final elapsed = _clock.lastElapsedDuration ?? Duration.zero;
    final seconds = elapsed.inMicroseconds ~/ _second.inMicroseconds;
    final heat = elapsed.inMicroseconds ~/ _heatStep.inMicroseconds;
    if (seconds == _ticks && heat == _heat) return;
    setState(() {
      while (_ticks < seconds) {
        _series.advance();
        _ticks++;
      }
      _heat = heat;
    });
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final window = MediaQuery.sizeOf(context);
    final gutter = EvSpace.gutterFor(window);
    final chrome = MediaQuery.paddingOf(context);
    final d = widget.downloads;

    Widget section(String title, String count, Widget child) => Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EvSectionHeader(title, count: count),
          const SizedBox(height: EvSpace.l),
          child,
        ],
      ),
    );

    return ListView(
      primary: true,
      padding: EdgeInsets.fromLTRB(
        gutter,
        chrome.top + gutter,
        gutter,
        26 + chrome.bottom,
      ),
      children: [
        EvHeadPanels(
          left: _RatePanel(downloads: d, series: _series.history),
          right: _SwarmPanel(downloads: d, heat: _heat),
        ),
        section(
          'Сейчас качается',
          '${d.torrents.length} '
              '${ruPlural(d.torrents.length, 'раздача', 'раздачи', 'раздач')}',
          d.torrents.isEmpty
              ? EvNothing(
                  icon: EvIcons.download,
                  title: 'Ничего не качается',
                  detail:
                      'Перетащите .torrent в окно или вставьте magnet-ссылку '
                      '— движок подхватит её сам',
                  action: EvMiniButton(
                    label: 'Вставить ссылку',
                    icon: EvIcons.magnet,
                    onPressed: () {},
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, t) in d.torrents.indexed) ...[
                      if (i > 0) const SizedBox(height: 11),
                      EvTorrentRow(torrent: t),
                    ],
                  ],
                ),
        ),
        if (d.queue.isNotEmpty)
          section(
            'В очереди',
            '${d.queue.length} '
                '${ruPlural(d.queue.length, 'раздача', 'раздачи', 'раздач')}',
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, q) in d.queue.indexed) ...[
                  if (i > 0) const SizedBox(height: 7),
                  EvQueueRow(item: q),
                ],
              ],
            ),
          ),
        SizedBox(height: ev.radii.r1),
      ],
    );
  }
}

/// Приём сейчас: крупное число, минута истории и четыре прибора.
class _RatePanel extends StatelessWidget {
  const _RatePanel({required this.downloads, required this.series});

  final EvDownloads downloads;
  final List<double> series;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final d = downloads;
    final rate = series.last;
    return EvPanel(
      glowCorner: true,
      grouped: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('ПРИЁМ · СЕЙЧАС', style: ev.text.label),
          const SizedBox(height: 8),
          EvBigNumber(rate.toStringAsFixed(2), unit: 'МБ/с'),
          const SizedBox(height: 10),
          EvRateGraph(series),
          const SizedBox(height: EvSpace.l),
          EvKpiGrid(
            items: [
              ('Отдача', formatRate(d.upKb), c.cool),
              ('Пик за час', formatRate(d.peakKb, digits: 1), c.hot2),
              ('Активных', '${d.active} / ${d.slots}', c.ink),
              ('На диск', formatRate(d.toDiskKb), c.ink),
            ],
          ),
        ],
      ),
    );
  }
}

/// Из чего состоит приём: кольцо частей и минута активности пиров.
class _SwarmPanel extends StatelessWidget {
  const _SwarmPanel({required this.downloads, required this.heat});

  final EvDownloads downloads;
  final int heat;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final parts = downloads.parts;
    return EvPanel(
      grouped: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('РОЙ · РАСПРЕДЕЛЕНИЕ ЧАСТЕЙ', style: ev.text.label),
          const SizedBox(height: 14),
          if (parts == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Text(
                'Частей нет: ни одна раздача не идёт',
                style: ev.text.data.copyWith(fontSize: 11.5),
              ),
            )
          else
            Row(
              children: [
                EvSwarmRing(
                  received: parts.received / parts.total,
                  inFlight: parts.inFlight / parts.total,
                  verifying: parts.verifying / parts.total,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Legend(
                        color: c.hot1,
                        label: 'Получено',
                        value: parts.received,
                      ),
                      _Legend(
                        color: c.cool,
                        label: 'В работе',
                        value: parts.inFlight,
                      ),
                      _Legend(
                        color: c.arc,
                        label: 'Проверка',
                        value: parts.verifying,
                      ),
                      _Legend(
                        color: c.ink.withValues(alpha: .12),
                        label: 'Осталось',
                        value: parts.remaining,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 18),
          Text('АКТИВНОСТЬ ПИРОВ · 60 С', style: ev.text.label),
          const SizedBox(height: 14),
          EvPeerHeat(tick: heat, live: downloads.torrents.isNotEmpty),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ev.text.body.copyWith(fontSize: 12.5),
            ),
          ),
          const SizedBox(width: 14),
          Text(formatGbDot(value), style: ev.text.dataStrong),
        ],
      ),
    );
  }
}
