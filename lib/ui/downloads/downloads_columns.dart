import 'package:flutter/material.dart';

import '../theme.dart';

/// Источники и очередь, расставленные по размеру окна.
class DownloadsColumns extends StatelessWidget {
  const DownloadsColumns({
    super.key,
    required this.page,
    required this.sources,
    required this.queue,
  });

  /// Размер всей страницы, а не свой: пороги ширины и высоты считаются от
  /// окна раздела, а колонки стоят в его нижней части.
  final BoxConstraints page;
  final Widget sources;
  final Widget queue;

  /// Ширина колонки источников. Уже — и названия релизов, которые здесь
  /// длинные, обрезаются до неузнаваемости.
  static const _sourcesWidth = 340.0;

  /// Ниже этой ширины источники и очередь в строку не помещаются.
  static const _wideWidth = 980.0;

  /// В низком окне полоса источников уступает место очереди: очередь
  /// отвечает на вопрос «что происходит», а пополнить её можно и
  /// перетаскиванием из библиотеки.
  static const _sourcesHeight = 360.0;

  @override
  Widget build(BuildContext context) {
    if (page.maxWidth >= _wideWidth) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: _sourcesWidth, child: sources),
          VerticalDivider(width: 1, color: context.colors.outline),
          Expanded(child: queue),
        ],
      );
    }
    if (page.maxHeight < _sourcesHeight) return queue;
    return Column(
      children: [
        // В узком окне источники остаются сверху полосой. Доли, а не
        // фиксированная высота: при крупном масштабе интерфейса в
        // минимальном окне полоса не влезала и выдавливала очередь за край.
        Flexible(flex: 2, child: sources),
        Divider(height: 1, color: context.colors.outline),
        Flexible(flex: 5, child: queue),
      ],
    );
  }
}
