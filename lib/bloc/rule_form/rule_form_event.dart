part of 'rule_form_bloc.dart';

sealed class RuleFormEvent extends Equatable {
  const RuleFormEvent();

  @override
  List<Object?> get props => [];
}

/// Набрали метку.
final class RuleLabelChanged extends RuleFormEvent {
  const RuleLabelChanged(this.label);

  final String label;

  @override
  List<Object?> get props => [label];
}

/// Набрали шаблон пути.
final class RuleTemplateChanged extends RuleFormEvent {
  const RuleTemplateChanged(this.template);

  final String template;

  @override
  List<Object?> get props => [template];
}

/// Переключили «только на этой системе».
final class RulePlatformOnlyChanged extends RuleFormEvent {
  const RulePlatformOnlyChanged({required this.only});

  final bool only;

  @override
  List<Object?> get props => [only];
}
