import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Поле ввода настройки с подписью слева — в столбец с остальными.
class SettingTextField extends StatelessWidget {
  const SettingTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.enabled,
    this.numeric = false,
    this.obscure = false,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;

  /// Только цифры — например, порт.
  final bool numeric;

  /// Скрыть набранное — пароль.
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: EvaporateLayout.settingLabelWidth,
            child: Text(label, style: context.text.body),
          ),
          SizedBox(
            width: 260,
            child: TextField(
              controller: controller,
              enabled: enabled,
              obscureText: obscure,
              keyboardType: numeric ? TextInputType.number : null,
              inputFormatters: numeric
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : null,
              decoration: const InputDecoration(isDense: true),
            ),
          ),
        ],
      ),
    );
  }
}
