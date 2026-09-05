import 'dart:io';

import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/navigation/navigation_bloc.dart';
import 'package:evaporate/core/save_path_template.dart';
import 'package:evaporate/models/game.dart';
import 'package:evaporate/models/save_profile.dart';
import 'package:evaporate/services/saves/save_path_finder.dart';
import 'package:evaporate/ui/library/saves_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/test_app.dart';

/// Раздел путей сохранений — то, ради чего приложение и затевалось:
/// снимок нельзя снять, пока не сказано, откуда брать файлы.
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await TestHarness.makeTempDir();
  });

  tearDown(() => TestHarness.removeTempDir(tmp));

  /// Файловые операции — через `runAsync`: внутри `testWidgets` настоящий
  /// ввод-вывод живёт в фейковом времени и не завершается никогда.
  Future<T> prepare<T>(WidgetTester tester, Future<T> Function() build) async {
    late T result;
    await tester.runAsync(() async => result = await build());
    return result;
  }

  /// Открывает страницу игры с заданными правилами путей.
  Future<TestHarness> openGame(
    WidgetTester tester, {
    List<SavePathRule> rules = const [],
    List<String> ludusaviTemplates = const [],
    List<SaveRoot> Function()? saveRoots,
    Locale? locale,
  }) async {
    final harness = TestHarness(tmp, saveRoots: saveRoots);
    addTearDown(harness.dispose);
    final id = harness.addGame(
      title: 'Тихая гавань',
      status: GameStatus.installed,
      installDir: p.join(tmp.path, 'games', 'quiet'),
    );
    await harness.pump(tester, locale: locale);

    if (rules.isNotEmpty || ludusaviTemplates.isNotEmpty) {
      final game = harness.library.state.gameById(id)!;
      harness.library.add(
        GameUpdated(
          game.copyWith(
            ludusaviTemplates: ludusaviTemplates,
            saveProfile: game.saveProfile.copyWith(rules: rules),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    harness.nav.add(GameOpened(id));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    return harness;
  }

  SavePathRule ruleOf({
    String id = 'rule-1',
    String label = SavePathRule.defaultLabel,
    required String template,
    String? platform,
  }) => SavePathRule(
    id: id,
    label: label,
    template: template,
    platform: platform,
  );

  testWidgets('без путей раздел объясняет, чего не хватает', (tester) async {
    await openGame(tester);

    expect(find.text('Папки сохранений'), findsOneWidget);
    expect(find.textContaining('Пути не заданы'), findsOneWidget);
  });

  // Снимать нечего, пока не сказано откуда: доступная кнопка обещала бы
  // работу, которой не будет.
  testWidgets('без путей снимок снять нельзя', (tester) async {
    await openGame(tester);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Снять'),
    );
    expect(button.onPressed, isNull);
    expect(find.textContaining('Снимков пока нет'), findsOneWidget);
  });

  testWidgets('с заданным путём снимок снять можно', (tester) async {
    await openGame(
      tester,
      rules: [ruleOf(template: '${SavePathTemplate.appSupport}/Quiet/Saves')],
    );

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Снять'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('правило показывает свой шаблон, а не развёрнутый путь', (
    tester,
  ) async {
    const template = '${SavePathTemplate.appSupport}/Quiet/Saves';
    await openGame(tester, rules: [ruleOf(template: template)]);

    expect(find.text(template), findsOneWidget);
  });

  // Путь, которого на диске нет, — обычное дело до первого запуска игры,
  // но человек должен видеть, что снимать пока нечего.
  testWidgets('отсутствующая на диске папка помечается', (tester) async {
    await openGame(
      tester,
      rules: [ruleOf(template: '${SavePathTemplate.appSupport}/Нет/Такой')],
    );

    expect(find.text('нет на диске'), findsOneWidget);
  });

  testWidgets('существующая папка не помечается пропавшей', (tester) async {
    final dir = await prepare(
      tester,
      () => Directory(p.join(tmp.path, 'saves')).create(recursive: true),
    );

    await openGame(tester, rules: [ruleOf(template: dir.path)]);

    expect(find.text('нет на диске'), findsNothing);
  });

  // Абсолютный путь на другом устройстве не развернётся, и снимок туда
  // не ляжет — молчать об этом нельзя.
  testWidgets('непереносимый путь помечается прямо в списке', (tester) async {
    await openGame(tester, rules: [ruleOf(template: '/opt/quiet/saves')]);

    expect(find.text('непереносимый путь'), findsOneWidget);
  });

  testWidgets('правило для одной системы помечено её именем', (tester) async {
    await openGame(
      tester,
      rules: [
        ruleOf(
          template: '${SavePathTemplate.appSupport}/Quiet',
          platform: 'windows',
        ),
      ],
    );

    expect(find.text('Windows'), findsOneWidget);
  });

  testWidgets('крестик убирает правило из профиля игры', (tester) async {
    final harness = await openGame(
      tester,
      rules: [
        ruleOf(id: 'a', template: '${SavePathTemplate.appSupport}/Quiet/A'),
        ruleOf(
          id: 'b',
          label: 'Настройки',
          template: '${SavePathTemplate.appSupport}/Quiet/B',
        ),
      ],
    );
    expect(harness.library.state.games.single.saveProfile.rules, hasLength(2));

    await tester.tap(find.byTooltip('Убрать путь').first);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    final left = harness.library.state.games.single.saveProfile.rules;
    expect(left, hasLength(1));
    expect(left.single.id, 'b');
  });

  testWidgets('переключатель автоснимка правит профиль игры', (tester) async {
    final harness = await openGame(
      tester,
      rules: [ruleOf(template: '${SavePathTemplate.appSupport}/Quiet')],
    );
    expect(
      harness.library.state.games.single.saveProfile.autoSnapshotOnExit,
      isTrue,
    );

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      harness.library.state.games.single.saveProfile.autoSnapshotOnExit,
      isFalse,
    );
  });

  testWidgets('запомненные пути базы показываются отдельным списком', (
    tester,
  ) async {
    await openGame(
      tester,
      ludusaviTemplates: ['${SavePathTemplate.home}/.local/share/quiet/*'],
    );

    expect(find.text('Запомненные пути Ludusavi'), findsOneWidget);
  });

  // Метка по умолчанию не переводится намеренно: по ней правила
  // сопоставляются между устройствами. Переводится только показ, а хранится
  // она как есть — иначе снимок с русской машины не сошёлся бы с правилом
  // на английской.
  testWidgets('метка по умолчанию переводится на показ, но не в хранении', (
    tester,
  ) async {
    final harness = await openGame(
      tester,
      rules: [ruleOf(template: '${SavePathTemplate.appSupport}/Quiet')],
      locale: const Locale('en'),
    );

    // «Saves» есть и в рельсе разделов, поэтому смотрим внутрь карточки.
    expect(
      find.descendant(
        of: find.byType(SavePathsSection),
        matching: find.text('Saves'),
      ),
      findsOneWidget,
    );
    expect(find.text(SavePathRule.defaultLabel), findsNothing);
    expect(
      harness.library.state.games.single.saveProfile.rules.single.label,
      SavePathRule.defaultLabel,
    );
  });

  testWidgets('своя метка не переводится ни при каком языке', (tester) async {
    await openGame(
      tester,
      rules: [
        ruleOf(
          label: 'Профиль игрока',
          template: '${SavePathTemplate.appSupport}/Quiet',
        ),
      ],
      locale: const Locale('en'),
    );

    expect(find.text('Профиль игрока'), findsOneWidget);
  });

  group('подсказки после выхода из игры', () {
    /// Папка со свежим файлом внутри и корень, в котором её видно.
    Future<Directory> watchedDir(WidgetTester tester, String name) =>
        prepare(tester, () async {
          final dir = Directory(p.join(tmp.path, 'watched', name));
          await dir.create(recursive: true);
          await File(p.join(dir.path, 'slot1.sav')).writeAsString('прогресс');
          return dir;
        });

    /// Просит блок осмотреть корни и ждёт, пока подсказки появятся.
    ///
    /// Обход настоящий, поэтому крутится через `runAsync`, а ожидание идёт
    /// по условию: на машине сборки обход занимает другое время.
    Future<void> askForHints(WidgetTester tester, TestHarness harness) async {
      final game = harness.library.state.games.single;
      harness.library.add(
        SaveHintsRequested(
          game: game,
          since: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      );

      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (harness.library.state.hintsFor(game.id).isEmpty) {
        if (DateTime.now().isAfter(deadline)) fail('подсказки не появились');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    Future<TestHarness> withHints(WidgetTester tester) async {
      await watchedDir(tester, 'Тихая гавань');
      final harness = await openGame(
        tester,
        saveRoots: () => [
          SaveRoot(
            path: p.join(tmp.path, 'watched'),
            insideKnownGamesFolder: true,
          ),
        ],
      );
      await askForHints(tester, harness);
      return harness;
    }

    testWidgets('изменившаяся папка предлагается, а не пишется молча', (
      tester,
    ) async {
      final harness = await withHints(tester);

      expect(find.text('Изменились, пока игра работала'), findsOneWidget);
      // Предложение — ещё не правило.
      expect(harness.library.state.games.single.saveProfile.rules, isEmpty);
    });

    testWidgets('принятая подсказка становится правилом', (tester) async {
      final harness = await withHints(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Добавить').last);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      final rules = harness.library.state.games.single.saveProfile.rules;
      expect(rules, hasLength(1));
      expect(rules.single.template, contains('Тихая гавань'));
      expect(find.text('Изменились, пока игра работала'), findsNothing);
    });

    testWidgets('«Не то» убирает подсказки, ничего не записав', (tester) async {
      final harness = await withHints(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Не то'));
      await tester.pumpAndSettle();

      expect(find.text('Изменились, пока игра работала'), findsNothing);
      expect(harness.library.state.games.single.saveProfile.rules, isEmpty);
    });
  });
}
