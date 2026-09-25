import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../glass/ev_glass.dart';
import '../settings/settings_data.dart';
import 'ev_top_bar.dart';

/// Строка клавиатурных подсказок внизу окна — подпись приложения,
/// перенесённая из работающего продукта. Её нельзя терять при редизайне.
///
/// Как и верхняя полоса, сделана из матового стекла: полка уходит под неё
/// при прокрутке.
class EvHintsBar extends StatelessWidget {
  const EvHintsBar({
    super.key,
    this.hints,
    this.ready = true,
    this.status,
    this.statusColor,
  });

  /// Подсказки. `null` — из таблицы клавиш настроек: строка и таблица
  /// не должны расходиться.
  final List<(String, String)>? hints;

  /// Состояние движка справа: готов или занят.
  final bool ready;

  /// Состояние движка словом — вместо «готов» и «занят», когда оно
  /// известно точнее: остановлен, запускается, отказал.
  final String? status;

  /// Цвет точки и слова при [status].
  final Color? statusColor;

  @override
  Widget build(BuildContext context) {
    final ev = context.ev;
    final c = ev.colors;
    final l = L.of(context);
    final label = ev.text.data.copyWith(color: c.ink4, fontSize: 10.5);
    final gutter = EvSpace.gutterFor(MediaQuery.sizeOf(context));
    return EvGlass(
      grouped: true,
      // Подписи здесь самые тихие в системе (ink4), а под полосой едут
      // обложки: стекло тут плотнее и темнее, иначе строку не прочесть.
      style: EvGlassStyle.frost.copyWith(tintAlpha: 0.74, brightness: 0.5),
      borderRadius: BorderRadius.zero,
      // Стык с экраном — сверху, как `border-top` в прототипе.
      rim: const {AxisDirection.up},
      padding: EdgeInsets.symmetric(horizontal: gutter),
      child: SizedBox(
        height: EvSpace.hintsHeight,
        child: Row(
          children: [
            // Подсказки не переносятся: при нехватке места обрезаются справа,
            // статус движка остаётся видимым всегда.
            Expanded(
              // Неподвижный горизонтальный скролл даёт строке бесконечную
              // ширину: обычный Row внутри ClipRect всё равно ругался бы
              // на переполнение, а так лишнее просто обрезается.
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  children: [
                    for (final (key, action) in hints ?? evHints) ...[
                      EvKey(key),
                      const SizedBox(width: 7),
                      Text(action, style: label),
                      const SizedBox(width: 20),
                    ],
                  ],
                ),
              ),
            ),
            Text(
              '● ${status ?? (ready ? l.evHintsReady : l.evHintsBusy)}',
              style: label.copyWith(
                color: statusColor ?? (ready ? EvColors.ok : c.cool),
              ),
            ),
            const SizedBox(width: 20),
            Text('© 2026 EVAPORATE', style: label),
          ],
        ),
      ),
    );
  }
}
