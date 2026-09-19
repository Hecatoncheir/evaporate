import 'package:flutter/material.dart';

/// Кружок «идёт работа» на месте значка клавиши.
///
/// Размер задан жёстко и не растёт: он встаёт вместо значка в ряду
/// одинаковых клавиш, а `CircularProgressIndicator` без рамки занял бы всё
/// доступное место и разорвал бы строку.
class BusySpinner extends StatelessWidget {
  const BusySpinner({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: const CircularProgressIndicator(strokeWidth: 2),
  );
}
