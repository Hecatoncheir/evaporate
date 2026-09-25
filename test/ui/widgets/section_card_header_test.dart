import 'package:evaporate/ui/widgets/section_card_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/host_widget.dart';

/// Заголовок карточки: имя слева, клавиши справа, а в узкой карточке —
/// клавиши под именем, но не за краем.
void main() {
  Future<void> show(WidgetTester tester, double width) => tester.pumpWidget(
    hostWidget(
      Align(
        alignment: Alignment.topLeft,
        // Как в карточке: колонка, прижатая влево, даёт заголовку свободную
        // ширину, а не жёсткую — ровно в этих условиях он и сжимался.
        child: SizedBox(
          key: const ValueKey('card'),
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionCardHeader(
                title: 'Метаданные игр',
                icon: Icons.info_outline,
                trailing: OutlinedButton(
                  onPressed: () {},
                  child: const Text('Поискать для всех'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  // Перенос сжимался по своей строке, и клавиши вставали вплотную за
  // именем: разносить их к правому краю было не по чему.
  testWidgets('в широкой карточке клавиши стоят у правого края', (
    tester,
  ) async {
    await show(tester, 600);

    final card = tester.getRect(find.byKey(const ValueKey('card')));
    final title = tester.getRect(find.text('Метаданные игр'));
    final button = tester.getRect(find.byType(OutlinedButton));
    expect(button.right, closeTo(card.right, 0.5));
    expect(button.center.dy, closeTo(title.center.dy, 1));
  });

  testWidgets('в узкой карточке клавиши уходят под имя, а не за край', (
    tester,
  ) async {
    await show(tester, 240);

    final card = tester.getRect(find.byKey(const ValueKey('card')));
    final title = tester.getRect(find.text('Метаданные игр'));
    final button = tester.getRect(find.byType(OutlinedButton));
    expect(button.top, greaterThan(title.bottom));
    expect(button.right, lessThanOrEqualTo(card.right));
    expect(tester.takeException(), isNull);
  });
}
