import 'package:evaporate/models/app_section.dart';
import 'package:evaporate/ui/shell/navigation_key.dart';
import 'package:evaporate/ui/shell/queue_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/host_widget.dart';

/// Клавиша обоймы: значок раздела и метка числа задач в её углу.
void main() {
  Future<void> show(WidgetTester tester, int queued) => tester.pumpWidget(
    hostWidget(
      Align(
        alignment: Alignment.topLeft,
        child: NavigationKey(
          targetKey: GlobalKey(),
          section: AppSection.downloads,
          label: 'Загрузки',
          icon: Icons.download_outlined,
          selected: false,
          queued: queued,
        ),
      ),
    ),
  );

  // Метка отсчитывалась от значка, а не от клавиши, и ложилась на сам
  // значок: пока шли загрузки, раздела было не узнать, а трёхзначное число
  // вылезало за левый край клавиши.
  for (final queued in [3, 123]) {
    testWidgets('метка $queued стоит в углу клавиши и не закрывает значок', (
      tester,
    ) async {
      await show(tester, queued);

      final key = tester.getRect(find.byType(TextButton));
      final icon = tester.getRect(find.byType(Icon));
      final badge = tester.getRect(find.byType(QueueBadge));
      expect(key.contains(badge.topLeft), isTrue, reason: '$badge в $key');
      expect(key.contains(badge.bottomRight), isTrue, reason: '$badge в $key');
      expect(badge.contains(icon.center), isFalse, reason: '$badge на $icon');
      expect(badge.center.dx, greaterThan(icon.center.dx));
      expect(badge.center.dy, lessThan(icon.center.dy));
    });
  }
}
