import 'package:flutter/material.dart';

import '../theme.dart';

/// Ошибка того, что человек только что нажал сам. Закончившееся в фоне
/// идёт системным уведомлением, а не сюда: SnackBar некому увидеть, если
/// окно свёрнуто.
///
/// Заливка почти плотная, а не ступень шкалы: белому тексту на красном
/// нужен весь контраст.
void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(error.toString()),
      backgroundColor: context.colors.danger.withValues(alpha: 0.9),
    ),
  );
}

/// Итог того, что человек только что нажал сам.
void showInfo(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
