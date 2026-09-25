import 'package:flutter/material.dart';

import '../theme.dart';
import 'rack_navigation.dart';
import 'top_bar_actions.dart';
import 'top_bar_brand.dart';
import 'window_drag_area.dart';

/// Верхняя рейка: бренд и действия стоят по краям, а разделы — ровно по
/// центру доступной ширины. В узком окне разделы переезжают вниз.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: EvaporateLayout.topBarHeight,
    child: Stack(
      alignment: Alignment.center,
      children: [
        // Подложка рейки тянет окно: своей полосы заголовка у приложения
        // больше нет, и двигать окно человеку иначе нечем. Лежит ниже
        // всего остального, поэтому клавиши и обойма забирают нажатия себе,
        // а знак, название и просветы между ними — тянут.
        const WindowDragArea(),
        Row(
          children: [
            // Знак и название — не органы управления: нажатие проходит сквозь
            // них к подложке, которая тянет окно. Без этого текст забирал бы
            // нажатие себе (RenderParagraph отвечает на попадание), и окно
            // не тянулось бы за собственное имя — самое очевидное место,
            // чтобы взяться.
            IgnorePointer(child: TopBarBrand(compact: compact)),
            if (compact) ...[
              // В узком окне разделы остаются в рейке, а не уезжают вниз:
              // обойма сама прячет подписи и сжимается по месту. Прежде она
              // переезжала под содержимое и налезала на подсказки
              // управления в нижней строке.
              const SizedBox(width: EvaporateSpacing.cluster),
              const Expanded(child: Center(child: RackNavigation())),
              const SizedBox(width: EvaporateSpacing.cluster),
            ] else
              const Spacer(),
            const TopBarActions(),
          ],
        ),
        // В широком окне обойма стоит ровно по центру всей рейки, а не
        // между знаком и действиями: для этого она и лежит в Stack.
        if (!compact) const RackNavigation(),
      ],
    ),
  );
}
