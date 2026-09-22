import 'package:flutter/material.dart';

import 'busy_spinner.dart';

/// Обведённая клавиша, которая на время работы гаснет и крутит колесо
/// вместо значка.
///
/// Была выписана дважды — «Добавить в Steam» и «Найти в Steam», — и копии
/// различались только ключом занятости, событием и значком. Занятость
/// приходит снаружи: клавише незачем знать, какой блок её считает.
class BusyOutlinedButton extends StatelessWidget {
  const BusyOutlinedButton({
    super.key,
    required this.busy,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final bool busy;
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy ? const BusySpinner() : Icon(icon),
      label: Text(label),
    );
  }
}
