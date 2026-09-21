import 'dart:io';

import 'package:evaporate/bloc/library/library_bloc.dart';
import 'package:evaporate/bloc/saves/saves_bloc.dart';
import 'package:evaporate/bloc/settings/settings_bloc.dart';
import 'package:evaporate/core/app_paths.dart';
import 'package:evaporate/l10n/app_localizations.dart';
import 'package:evaporate/ui/saves/bulk_transfer_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/host_widget.dart';
import '../../support/temp_dir.dart';

/// Клавиши массовой загрузки решают судьбу чужого прогресса, и проверять
/// надо именно их, а не защиту под ними.
///
/// Сама защита от отката покрыта насквозь (`save_conflict_test.dart`): блок
/// с `overwriteNewer: false` пропускает игры, где здешние сохранения новее.
/// Но между этой защитой и человеком стоит диалог с тремя клавишами, две из
/// которых означают ровно противоположное. Поменяй их местами — и
/// приложение молча затрёт свежий прогресс там, где его просили сберечь, а
/// все тесты защиты останутся зелёными.
void main() {
  late Directory tmp;
  late AppPaths paths;
  late SettingsBloc settings;
  late LibraryBloc library;
  late _RecordingSaves saves;

  /// Ответ системного окна выбора папки. `null` — человек его закрыл:
  /// именно так отмену показывают все три настольные реализации плагина
  /// (пустой список путей превращается в `null`).
  late String? chosen;

  // Папку готовим снаружи: настоящий файловый I/O внутри testWidgets не
  // завершается никогда.
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_bulk_ui_');
    chosen = p.join(tmp.path, 'обмен');
    paths = AppPaths.custom(
      dataDir: p.join(tmp.path, 'data'),
      defaultInstallDir: p.join(tmp.path, 'games'),
    );
    settings = SettingsBloc(paths);
    library = LibraryBloc(
      automaticMetadata: false,
      paths: paths,
      settings: settings,
    );
    saves = _RecordingSaves(paths: paths, library: library, settings: settings);

    // Системное окно выбора папки в тесте не открыть: подменяем канал
    // плагина и отвечаем за него сами.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_picker, (call) async {
          if (call.method == 'getDirectoryPath') return chosen;
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_picker, null);
    await saves.close();
    await library.close();
    await settings.close();
    try {
      await deleteTempDir(tmp);
    } on FileSystemException {
      // Остатки временной папки на результат теста не влияют.
    }
  });

  Future<void> pumpCard(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<SettingsBloc>.value(value: settings),
          BlocProvider<LibraryBloc>.value(value: library),
          BlocProvider<SavesBloc>.value(value: saves),
        ],
        child: hostWidget(const BulkTransferCard()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Нажимает «Загрузить всё» и доводит дело до диалога о новых сохранениях.
  Future<void> openImportDialog(WidgetTester tester) async {
    final l = await _ru();
    await tester.tap(find.widgetWithText(OutlinedButton, l.importAll));
    await tester.pumpAndSettle();
    expect(
      find.text(l.importAllQuestion),
      findsOneWidget,
      reason: 'без диалога загрузка началась бы молча',
    );
  }

  testWidgets('«Пропустить новые» бережёт свежий прогресс', (tester) async {
    final l = await _ru();
    await pumpCard(tester);
    await openImportDialog(tester);

    await tester.tap(find.text(l.importSkipNewer));
    await tester.pumpAndSettle();

    final event = saves.events.single as BulkImportRequested;
    expect(event.sourceDir, chosen);
    expect(
      event.overwriteNewer,
      isFalse,
      reason: 'перепутанные клавиши затёрли бы то, что просили сберечь',
    );
  });

  testWidgets('«Даже поверх новых» разрешает перезапись', (tester) async {
    final l = await _ru();
    await pumpCard(tester);
    await openImportDialog(tester);

    await tester.tap(find.text(l.importOverwriteNewer));
    await tester.pumpAndSettle();

    final event = saves.events.single as BulkImportRequested;
    expect(event.sourceDir, chosen);
    expect(event.overwriteNewer, isTrue);
  });

  // Отказ — тоже ответ, и он обязан ничего не делать: диалог стоит
  // перед перезаписью сохранений всей библиотеки.
  testWidgets('отказ в диалоге не начинает загрузку', (tester) async {
    final l = await _ru();
    await pumpCard(tester);
    await openImportDialog(tester);

    await tester.tap(find.text(l.cancel));
    await tester.pumpAndSettle();

    expect(saves.events, isEmpty);
  });

  // Закрытое системное окно значит «передумал»: спрашивать после этого
  // не о чем, и подтверждать нечего.
  testWidgets('закрытое окно выбора папки не ведёт к диалогу', (tester) async {
    final l = await _ru();
    await pumpCard(tester);
    chosen = null;

    await tester.tap(find.widgetWithText(OutlinedButton, l.importAll));
    await tester.pumpAndSettle();

    expect(find.text(l.importAllQuestion), findsNothing);
    expect(saves.events, isEmpty);
  });

  // Выгрузка ничего не затирает, поэтому и не спрашивает.
  testWidgets('выгрузка уходит сразу в выбранную папку', (tester) async {
    final l = await _ru();
    await pumpCard(tester);

    await tester.tap(find.widgetWithText(FilledButton, l.exportAll));
    await tester.pumpAndSettle();

    expect(find.text(l.importAllQuestion), findsNothing);
    final event = saves.events.single as BulkExportRequested;
    expect(event.destinationDir, chosen);
  });
}

const _picker = MethodChannel('plugins.flutter.io/file_selector');

Future<L> _ru() => L.delegate.load(const Locale('ru'));

/// Блок, который события записывает, но не исполняет.
///
/// Проверяем здесь раскладку, а не перенос: настоящая массовая загрузка
/// пошла бы читать и писать файлы, а файловый I/O внутри testWidgets не
/// завершается. Записанное событие говорит ровно то, что нужно, — что
/// нажатая клавиша означает.
class _RecordingSaves extends SavesBloc {
  _RecordingSaves({
    required super.paths,
    required super.library,
    required super.settings,
  });

  final events = <SavesEvent>[];

  @override
  void add(SavesEvent event) => events.add(event);
}
