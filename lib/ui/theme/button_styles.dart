import 'package:flutter/material.dart';

import 'evaporate_theme.dart';
import 'palette.dart';

/// Варианты клавиш, которых нет у Material: опасная и компактная.
///
/// Прежде каждая выписывалась по месту `styleFrom` — опасная четырежды, —
/// и отличались они ровно тем, чем могут отличаться копии: одна красила
/// надпись, другая заливку, и никто не решал, как выглядит «опасно» вообще.
/// Как у ролей текста, это производное от палитры, а не отдельное
/// расширение темы.
class EvaporateButtons {
  const EvaporateButtons(this._colors);

  final EvaporatePalette _colors;

  /// Текстовая клавиша необратимого: удалить, отменить с файлами.
  ButtonStyle get dangerText =>
      TextButton.styleFrom(foregroundColor: _colors.danger);

  /// Залитая клавиша необратимого — подтверждение в диалоге.
  ButtonStyle get dangerFilled =>
      FilledButton.styleFrom(backgroundColor: _colors.danger);

  /// Залитая клавиша в плотной карточке, рядом с полями и списками.
  ButtonStyle get compactFilled => FilledButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  );
}

/// Короткий доступ к вариантам клавиш: `context.buttons.dangerText`.
extension EvaporateButtonsAccess on BuildContext {
  EvaporateButtons get buttons => EvaporateButtons(colors);
}
