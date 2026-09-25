import 'dart:io';
import 'dart:ui';

import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/input/gamepad_binding.dart';
import 'package:evaporate/input/input_scope.dart';
import 'package:evaporate/l10n/app_localizations_ru.dart';
import 'package:evaporate/models/app_section.dart';
import 'package:evaporate/ui/settings/deadzone_slider.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:evaporate/ui/widgets/launcher_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/host_widget.dart';
import '../../support/test_app.dart';

/// С клавиатуры, геймпада и диктором видно и доступно то же, что мышью.
void main() {
  final l = LRu();
  // Временная папка — снаружи `testWidgets`: настоящий ввод-вывод внутри
  // него не завершается.
  late Directory tmp;
  setUp(() async => tmp = await TestHarness.makeTempDir());
  tearDown(() => TestHarness.removeTempDir(tmp));

  // Дошедший до главной клавиши стрелками не знал, что он на ней: у неё не
  // было состояния фокуса — только бледная заливка поверх золота.
  testWidgets('главная клавиша показывает фокус кантом', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        Center(
          child: LauncherActionButton(
            label: 'Играть',
            icon: Icons.play_arrow,
            tone: LauncherTone.launch,
            onPressed: () {},
          ),
        ),
      ),
    );

    BoxDecoration face() =>
        tester
                .widget<AnimatedContainer>(
                  find.descendant(
                    of: find.byType(LauncherActionButton),
                    matching: find.byType(AnimatedContainer),
                  ),
                )
                .decoration!
            as BoxDecoration;

    expect(face().border, isNull);
    // Узел фокуса — у `InkWell` внутри клавиши, над её надписью.
    Focus.of(tester.element(find.text('Играть'))).requestFocus();
    await tester.pumpAndSettle();
    expect(face().border, isNotNull);
  });

  // Геймпад приходит не клавишами, а действиями: влево и вправо уводили к
  // соседнему элементу, и мёртвую зону с самого геймпада было не поменять.
  testWidgets('ползунок мёртвой зоны сдвигается шагом с геймпада', (
    tester,
  ) async {
    var binding = const GamepadBinding();
    await tester.pumpWidget(
      hostWidget(
        StatefulBuilder(
          builder: (context, setState) => DeadzoneSlider(
            binding: binding,
            onChanged: (value) => setState(() => binding = value),
          ),
        ),
      ),
    );
    final slider = find.byType(Slider);
    final context = tester.element(slider);

    final before = binding.deadzone;
    Actions.invoke(context, const AdjustValueIntent(1));
    await tester.pump();

    expect(binding.deadzone, closeTo(before + 0.05, 1e-9));
    expect(binding.releaseZone, closeTo(binding.deadzone * 0.7, 1e-9));
  });

  // Выбранная клавиша обоймы звучала для диктора ровно как все остальные.
  testWidgets('диктор слышит, какой раздел открыт', (tester) async {
    final harness = TestHarness(tmp);
    addTearDown(harness.dispose);
    await harness.pump(tester);
    final handle = tester.ensureSemantics();

    harness.nav.add(const SectionSelected(AppSection.downloads));
    await tester.pumpAndSettle();

    bool selected(String label) =>
        tester
            .getSemantics(find.bySemanticsLabel(label).first)
            .getSemanticsData()
            .flagsCollection
            .isSelected ==
        Tristate.isTrue;
    expect(selected(l.downloads), isTrue);
    expect(selected(l.settings), isFalse);
    handle.dispose();
  });
}
