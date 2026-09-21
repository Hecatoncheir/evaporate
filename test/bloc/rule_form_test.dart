import 'package:evaporate/bloc/rule_form/rule_form_bloc.dart';
import 'package:evaporate/core/format.dart';
import 'package:evaporate/core/save_path_template.dart';
import 'package:evaporate/models/save_profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// Правило пути сохранений принимают по трём правилам, и каждое оплачено:
/// пустой шаблон разворачивался в рабочую папку приложения, занятая метка
/// рассыпала сопоставление между устройствами, а путь без плейсхолдера на
/// другой машине не разворачивается ни во что осмысленное.
void main() {
  RuleFormBloc form({
    String label = '',
    String template = '',
    SaveProfile profile = const SaveProfile(),
    String? gameDir,
  }) {
    final bloc = RuleFormBloc(
      label: label,
      template: template,
      profile: profile,
      gameDir: gameDir,
    );
    addTearDown(bloc.close);
    return bloc;
  }

  /// Даёт блоку доработать: событие доходит не мгновенно.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  test('клавиша права с первого кадра, а не после первого нажатия', () {
    expect(form(template: '{APPSUPPORT}/Игра').state.canSave, isTrue);
    expect(form().state.canSave, isFalse);
  });

  // Пустой шаблон развернулся бы в рабочую папку процесса, а восстановление
  // с очисткой цели её бы и очистило.
  test('пустой шаблон сохранить нельзя', () async {
    final bloc = form(template: '{APPSUPPORT}/Игра');

    bloc.add(const RuleTemplateChanged('   '));
    await settle();

    expect(bloc.state.canSave, isFalse);
  });

  // По метке правила сходятся между устройствами: две одинаковые сделали бы
  // оба правила непереносимыми.
  test('занятая метка гасит клавишу и говорит об этом', () async {
    final bloc = form(
      template: '{APPSUPPORT}/Игра',
      profile: const SaveProfile(
        rules: [
          SavePathRule(id: 'r1', label: 'Профиль', template: '{DOCS}/Игра'),
        ],
      ),
    );

    bloc.add(const RuleLabelChanged('профиль'));
    await settle();

    expect(bloc.state.labelTaken, isTrue);
    expect(bloc.state.canSave, isFalse);
  });

  // Метка по умолчанию — константа, а не перевод: записанное «Saves» с
  // английского интерфейса не сошлось бы с «Сохранениями» на русском.
  test('пустая метка записывается как «Сохранения»', () {
    final draft = form(template: '{APPSUPPORT}/Игра').state.draft;

    expect(draft.label, SavePathRule.defaultLabel);
  });

  test('пробелы по краям не уезжают в правило', () async {
    final bloc = form();

    bloc
      ..add(const RuleLabelChanged('  Профиль  '))
      ..add(const RuleTemplateChanged('  {APPSUPPORT}/Игра  '));
    await settle();

    expect(bloc.state.draft.label, 'Профиль');
    expect(bloc.state.draft.template, '{APPSUPPORT}/Игра');
  });

  test('путь без плейсхолдера помечается непереносимым', () async {
    final bloc = form(template: '{APPSUPPORT}/Игра');
    expect(bloc.state.portable, isTrue);

    bloc.add(const RuleTemplateChanged('/абсолютный/путь'));
    await settle();

    expect(bloc.state.portable, isFalse);
    // Непереносимость — предупреждение, а не отказ: путь может быть верным
    // именно на этой машине.
    expect(bloc.state.canSave, isTrue);
  });

  test('предпросмотр разворачивает шаблон папкой игры', () async {
    final bloc = form(gameDir: '/игры/Тихая гавань');

    bloc.add(const RuleTemplateChanged('{GAME}/saves'));
    await settle();

    expect(
      bloc.state.expanded,
      SavePathTemplate.expand('{GAME}/saves', gameDir: '/игры/Тихая гавань'),
    );
  });

  // Правило «только на этой системе» сужает и проверку метки: на другой
  // системе то же имя займёт другое правило.
  test('галочка системы уходит в правило', () async {
    final bloc = form(template: '{APPSUPPORT}/Игра');

    bloc.add(const RulePlatformOnlyChanged(only: true));
    await settle();

    expect(bloc.state.draft.currentPlatformOnly, isTrue);
    expect(currentPlatformKey(), isNotEmpty);
  });

  // Выбрать «Документы» в диалоге — одно нажатие, а восстановление с
  // очисткой заменило бы их целиком файлами снимка.
  test('системная папка целиком сохранения не получает', () async {
    final bloc = form(template: '{DOCUMENTS}/Игра');
    expect(bloc.state.tooBroad, isFalse);

    bloc.add(const RuleTemplateChanged(SavePathTemplate.documents));
    await settle();

    expect(bloc.state.tooBroad, isTrue);
    expect(bloc.state.canSave, isFalse);
  });

  // `{GAME}` без известной папки игры — ещё не путь, и судить о нём рано.
  test('недоразвёрнутый шаблон широким не считается', () {
    expect(form(template: '{GAME}').state.tooBroad, isFalse);
    expect(form(template: '{GAME}', gameDir: '/opt/hk').state.tooBroad, isTrue);
  });
}
