/// Что человек выбрал в окне восстановления.
class RestoreOptions {
  const RestoreOptions({required this.backupCurrent, required this.wipeTarget});

  /// Снять резервную копию здешних сохранений перед распаковкой.
  final bool backupCurrent;

  /// Стереть целевую папку до распаковки.
  final bool wipeTarget;
}
