import 'package:flutter/material.dart';

import '../theme.dart';

/// Ошибка того, что человек только что нажал сам. Закончившееся в фоне
/// идёт системным уведомлением, а не сюда: SnackBar некому увидеть, если
/// окно свёрнуто.
///
/// Заливка плотная и с парной надписью: прежде полупрозрачный красный с
/// обычным текстом давал около 3:1 в обеих схемах, а комментарий здесь
/// уверял, что текст белый.
void showError(BuildContext context, Object error) {
  final colors = context.colors;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(error.toString(), style: TextStyle(color: colors.onDanger)),
      backgroundColor: colors.dangerFill,
    ),
  );
}

/// Итог того, что человек только что нажал сам.
void showInfo(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
