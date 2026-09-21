part of 'rule_form_bloc.dart';

/// Правило, каким его записывают.
///
/// Метка по умолчанию — именно константа, а не перевод. Показывают её
/// переведённой (`ruleLabelText`), но хранят и сопоставляют как есть:
/// правила сходятся между устройствами по метке, и записанное здесь
/// «Saves» с английского интерфейса не сошлось бы с «Сохранениями» на
/// русском. Сейв просто не восстановился бы, и никто не догадался бы
/// почему.
class RuleDraft extends Equatable {
  const RuleDraft(
    this.label,
    this.template, {
    required this.currentPlatformOnly,
  });

  final String label;
  final String template;
  final bool currentPlatformOnly;

  @override
  List<Object?> get props => [label, template, currentPlatformOnly];
}

/// Набранное и то, что из него следует.
class RuleForm extends Equatable {
  const RuleForm({
    this.label = '',
    this.template = '',
    this.currentPlatformOnly = false,
    this.expanded = '',
    this.portable = true,
    this.labelTaken = false,
    this.tooBroad = false,
  });

  final String label;
  final String template;
  final bool currentPlatformOnly;

  /// Во что шаблон разворачивается здесь и сейчас.
  final String expanded;

  /// Шаблон переживёт переезд на другое устройство. Путь без плейсхолдера
  /// там не развернётся ни во что осмысленное.
  final bool portable;

  /// Такая метка у игры уже есть.
  final bool labelTaken;

  /// Путь слишком широк для сохранений: «Документы», домашняя папка,
  /// корень диска (`SavePathTemplate.isTooBroad`). Снимок унёс бы его
  /// целиком, а восстановление с очисткой — заменило бы.
  final bool tooBroad;

  /// Правило, каким его запишут: метка без пробелов по краям, пустая —
  /// значит «Сохранения».
  RuleDraft get draft {
    final trimmed = label.trim();
    return RuleDraft(
      trimmed.isEmpty ? SavePathRule.defaultLabel : trimmed,
      template.trim(),
      currentPlatformOnly: currentPlatformOnly,
    );
  }

  /// Пустой шаблон развернулся бы в рабочую папку процесса, занятая
  /// метка сделала бы оба правила непереносимыми, а слишком широкий путь
  /// не развернётся вовсе — `SavePathRule.resolve` ему откажет.
  bool get canSave => draft.template.isNotEmpty && !labelTaken && !tooBroad;

  RuleForm resolved({
    required String expanded,
    required bool portable,
    required bool labelTaken,
    required bool tooBroad,
  }) => RuleForm(
    label: label,
    template: template,
    currentPlatformOnly: currentPlatformOnly,
    expanded: expanded,
    portable: portable,
    labelTaken: labelTaken,
    tooBroad: tooBroad,
  );

  @override
  List<Object?> get props => [
    label,
    template,
    currentPlatformOnly,
    expanded,
    portable,
    labelTaken,
    tooBroad,
  ];
}
