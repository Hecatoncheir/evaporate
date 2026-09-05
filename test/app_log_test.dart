import 'dart:io';

import 'package:evaporate/l10n/app_localizations.dart';
import 'package:evaporate/services/system/app_log.dart';
import 'package:evaporate/ui/settings/log_card.dart';
import 'package:evaporate/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Журнал нужен ровно затем, что семь десятков мест в приложении гасят
/// ошибку молча: без него на «снимок не снялся» смотреть нечего.
void main() {
  late Directory tmp;
  late AppLog log;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_log_');
    log = AppLog(
      path: p.join(tmp.path, 'evaporate.log'),
      previousPath: p.join(tmp.path, 'evaporate.log.1'),
    );
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('запись доходит до файла вместе со временем', () async {
    log.write('снимок не снялся', const FileSystemException('нет прав'));
    await log.flush();

    final lines = await log.tail();
    expect(lines, hasLength(1));
    expect(lines.single, contains('снимок не снялся'));
    expect(lines.single, contains('нет прав'));
    // Отметка времени: без неё запись не соотнести с тем, что человек делал.
    expect(
      RegExp(r'^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d ').hasMatch(lines.single),
      isTrue,
    );
  });

  test('порядок записей сохраняется', () async {
    for (var i = 0; i < 20; i++) {
      log.write('запись $i');
    }
    await log.flush();

    final lines = await log.tail();
    expect(lines, hasLength(20));
    expect(lines.first, contains('запись 0'));
    expect(lines.last, contains('запись 19'));
  });

  // Иначе журнал незаметно съел бы диск у того, у кого что-то ломается
  // регулярно, — то есть ровно у того, кому он нужнее всего.
  test('переполнение поворачивает поколение, а не растёт дальше', () async {
    final small = AppLog(
      path: p.join(tmp.path, 'small.log'),
      previousPath: p.join(tmp.path, 'small.log.1'),
      maxBytes: 200,
    );

    for (var i = 0; i < 40; i++) {
      small.write('строка достаточной длины номер $i');
    }
    await small.flush();

    expect(
      File(p.join(tmp.path, 'small.log')).lengthSync(),
      lessThanOrEqualTo(400),
    );
    expect(File(p.join(tmp.path, 'small.log.1')).existsSync(), isTrue);
  });

  // Беда у самой границы поколений иначе оказалась бы разрезанной пополам.
  test('показ берёт оба поколения подряд', () async {
    final small = AppLog(
      path: p.join(tmp.path, 'small.log'),
      previousPath: p.join(tmp.path, 'small.log.1'),
      maxBytes: 120,
    );
    small.write('самая первая запись подлиннее, чтобы перевалить предел');
    await small.flush();
    small.write('вторая запись');
    await small.flush();

    final lines = await small.tail();
    expect(lines.join('\n'), contains('самая первая запись'));
    expect(lines.join('\n'), contains('вторая запись'));
  });

  test('показ отдаёт только хвост', () async {
    for (var i = 0; i < 50; i++) {
      log.write('запись $i');
    }
    await log.flush();

    final lines = await log.tail(lines: 10);
    expect(lines, hasLength(10));
    expect(lines.last, contains('запись 49'));
  });

  test('очистка убирает оба поколения', () async {
    log.write('что-то было');
    await log.flush();

    await log.clear();

    expect(await log.tail(), isEmpty);
  });

  // Журнал не вправе стать новым источником бед: он пишется как раз тогда,
  // когда что-то уже пошло не так.
  test('недоступный путь не роняет запись', () async {
    final broken = AppLog(
      path: p.join(tmp.path, 'нет-такой-папки', '\u0000', 'x.log'),
      previousPath: p.join(tmp.path, 'x.log.1'),
    );

    broken.write('в никуда');

    await expectLater(broken.flush(), completes);
  });

  test('журнал без пути молчит и ничего не пишет', () async {
    final silent = AppLog(path: '', previousPath: '');

    silent.write('никуда');
    await silent.flush();

    expect(await silent.tail(), isEmpty);
  });

  // Смысл журнала не в самой записи, а в том, что до него доходят ошибки,
  // о которых человек узнал бы только из исчезнувшего SnackBar.
  testWidgets('карточка показывает записанное и умеет его стереть', (
    tester,
  ) async {
    // Запись — тоже настоящий файловый ввод-вывод, и в фейковом времени
    // теста она не завершится: сюда её пускать нельзя даже до pumpWidget.
    await tester.runAsync(() async {
      log.write('снимок не снялся: нет прав');
      await log.flush();
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        locale: const Locale('ru'),
        theme: EvaporateTheme.dark(),
        home: Scaffold(
          body: ListView(children: [LogCard(log: log)]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // До нажатия журнал не читается: он может быть большим.
    expect(find.textContaining('снимок не снялся'), findsNothing);

    await _press(tester, find.widgetWithText(OutlinedButton, 'Показать'));
    await _untilVisible(tester, 'снимок не снялся');
    expect(find.textContaining('снимок не снялся'), findsOneWidget);

    await _press(tester, find.widgetWithText(TextButton, 'Очистить'));
    await _untilVisible(tester, 'Журнал пуст');
    expect(find.textContaining('снимок не снялся'), findsNothing);
    expect(find.textContaining('Журнал пуст'), findsOneWidget);
  });
}

/// Нажатие, после которого пойдёт настоящий файловый ввод-вывод.
///
/// Само нажатие — внутри `runAsync`: начатое в фейковом времени теста чтение
/// с диска не сдвинется с места, сколько потом ни прокручивай кадры.
Future<void> _press(WidgetTester tester, Finder button) async {
  await tester.runAsync(() async {
    await tester.tap(button);
    await tester.pump();
  });
}

/// Ждёт появления текста по условию.
///
/// Опрос идёт **снаружи** `runAsync`: кадры внутри него в цикле не идут, и
/// цикл с `pump` там просто зависает.
Future<void> _untilVisible(WidgetTester tester, String text) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (find.textContaining(text).evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) fail('не дождались «$text»');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}
