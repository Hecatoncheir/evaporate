/// Правка выбора — функцией от текущего, а не готовым значением: две
/// галочки, нажатые между кадрами, иначе затирали бы одна другую. Так же
/// устроен `SettingsPatched`.
typedef RestoreOptionsPatch = RestoreOptions Function(RestoreOptions current);

/// Что человек выбрал в окне восстановления.
class RestoreOptions {
  const RestoreOptions({required this.backupCurrent, required this.wipeTarget});

  /// Снять резервную копию здешних сохранений перед распаковкой.
  final bool backupCurrent;

  /// Стереть целевую папку до распаковки.
  final bool wipeTarget;

  RestoreOptions copyWith({bool? backupCurrent, bool? wipeTarget}) =>
      RestoreOptions(
        backupCurrent: backupCurrent ?? this.backupCurrent,
        wipeTarget: wipeTarget ?? this.wipeTarget,
      );
}
