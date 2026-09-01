import 'package:equatable/equatable.dart';

/// Одноразовое сообщение для UI. [seq] нужен, чтобы два одинаковых текста
/// подряд считались разными состояниями и SnackBar показался дважды.
class Notice extends Equatable {
  const Notice({
    required this.message,
    required this.seq,
    this.isError = false,
  });

  final String message;
  final int seq;
  final bool isError;

  @override
  List<Object?> get props => [message, seq, isError];
}
