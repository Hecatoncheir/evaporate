import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../core/format.dart';
import '../../core/save_path_template.dart';
import '../../models/save_profile.dart';

part 'rule_form_event.dart';
part 'rule_form_state.dart';

/// Правило пути сохранений, пока его набирают.
///
/// Блок, а не `setState` на каждое нажатие: считается тут не показ, а
/// правила, которыми это правило принимают, — можно ли сохранить, занята
/// ли метка, развернётся ли шаблон во что-нибудь осмысленное на другом
/// устройстве. Проверить их через окно стоит поднятого приложения, а так
/// это обычный тест.
///
/// Контроллеры текста остаются у окна: они не состояние, а ресурс.
class RuleFormBloc extends Bloc<RuleFormEvent, RuleForm> {
  RuleFormBloc({
    required String label,
    required String template,
    required this.profile,
    required this.gameDir,
    // Начальное состояние считается по тем же правилам: окно открывается
    // уже с подставленным путём, и клавиша обязана быть права с первого
    // кадра.
  }) : super(
         _resolve(RuleForm(label: label, template: template), profile, gameDir),
       ) {
    on<RuleLabelChanged>((event, emit) => emit(_form(label: event.label)));
    on<RuleTemplateChanged>(
      (event, emit) => emit(_form(template: event.template)),
    );
    on<RulePlatformOnlyChanged>(
      (event, emit) => emit(_form(currentPlatformOnly: event.only)),
    );
  }

  /// Уже заданные правила игры: метка нового не должна совпасть ни с одной
  /// из них — по метке правила сходятся между устройствами.
  final SaveProfile profile;

  /// Папка игры для `{GAME}` — без неё предпросмотр показал бы шаблон
  /// вместо пути.
  final String? gameDir;

  RuleForm _form({
    String? label,
    String? template,
    bool? currentPlatformOnly,
  }) => _resolve(
    RuleForm(
      label: label ?? state.label,
      template: template ?? state.template,
      currentPlatformOnly: currentPlatformOnly ?? state.currentPlatformOnly,
    ),
    profile,
    gameDir,
  );

  /// Что следует из набранного: куда развернётся, переживёт ли переезд,
  /// не занята ли метка и не слишком ли широк путь для сохранений.
  static RuleForm _resolve(
    RuleForm form,
    SaveProfile profile,
    String? gameDir,
  ) {
    final draft = form.draft;
    final expanded = SavePathTemplate.expand(draft.template, gameDir: gameDir);
    return form.resolved(
      expanded: expanded,
      portable: SavePathTemplate.isPortable(draft.template),
      labelTaken: profile.labelTaken(
        draft.label,
        platform: draft.currentPlatformOnly ? currentPlatformKey() : null,
      ),
      // Только о развёрнутом до конца: `{GAME}` без папки игры — ещё не путь.
      tooBroad:
          draft.template.isNotEmpty &&
          !expanded.contains('{') &&
          p.isAbsolute(expanded) &&
          SavePathTemplate.isTooBroad(expanded, gameDir: gameDir),
      overlaps: profile
          .overlapping(
            SavePathRule(id: '', label: draft.label, template: draft.template),
            gameDir: gameDir,
          )
          ?.label,
    );
  }
}
