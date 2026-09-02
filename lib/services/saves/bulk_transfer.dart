import 'package:path/path.dart' as p;

import '../../core/format.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';
import '../../models/bulk_report.dart';
import '../../models/game.dart';
import '../../models/save_snapshot.dart';
import 'save_manager.dart';

/// Чем закончился массовый перенос: отчёт для экрана и строка для SnackBar.
///
/// Собирается здесь, а не в блоке: формулировка — часть решения о том, что
/// считать бедой, а что нет, и держать её рядом с подсчётом честнее, чем
/// пересобирать из чисел на другом конце.
class BulkResult {
  const BulkResult({
    required this.report,
    required this.message,
    required this.isError,
  });

  final BulkReport report;
  final String message;

  /// Есть о чём тревожиться: не перенеслось или не нашлось, куда класть.
  final bool isError;
}

/// Перенос сохранений всей библиотеки: выгрузка пакетов в папку и разбор
/// такой папки обратно по играм.
///
/// Живёт отдельно от блока по двум причинам. Во-первых, это единственная
/// операция, которая идёт по всей библиотеке разом и заводит собственный
/// счёт исходов, — в блоке она занимала больше места, чем работа с самими
/// играми. Во-вторых, её можно проверить целиком, не поднимая ни блока, ни
/// состояния: на входе список игр, на выходе отчёт.
class BulkTransfer {
  BulkTransfer({
    required this.saves,
    L Function()? localizations,
    this.conflictTolerance = defaultConflictTolerance,
  }) : _localizations = localizations ?? _defaultLocalizations;

  final SaveManager saves;
  final L Function() _localizations;

  L get _l => _localizations();

  static L _defaultLocalizations() => LRu();

  /// Часы разных устройств расходятся, а время изменения файла хранится
  /// с разной точностью на разных файловых системах. Небольшую разницу
  /// за конфликт не считаем, иначе он будет срабатывать на ровном месте.
  static const defaultConflictTolerance = Duration(minutes: 2);

  final Duration conflictTolerance;

  /// Складывает по пакету на игру в [destinationDir].
  ///
  /// [onSnapshot] зовётся на каждый готовый снимок: библиотека большая,
  /// и список должен пополняться на глазах, а не одним прыжком в конце.
  Future<BulkResult> exportAll({
    required List<Game> games,
    required String destinationDir,
    required void Function(SaveSnapshot snapshot) onSnapshot,
  }) async {
    final entries = <BulkEntry>[];
    var exported = 0;
    var skipped = 0;
    final failed = <String>[];

    for (final game in games) {
      if (!game.saveProfile.isConfigured) {
        skipped++;
        entries.add(
          BulkEntry(
            title: game.title,
            outcome: BulkOutcome.skipped,
            detail: _l.detailNoSavePaths,
          ),
        );
        continue;
      }
      try {
        final snapshot = await saves.createSnapshot(game);
        onSnapshot(snapshot);

        await saves.exportSnapshot(
          snapshot,
          p.join(
            destinationDir,
            '${safeFileName(game.title)}${SaveSnapshot.fileExtension}',
          ),
        );
        exported++;
        entries.add(BulkEntry(title: game.title, outcome: BulkOutcome.applied));
      } on SaveException {
        // Пути заданы, но файлов ещё нет — это не ошибка переноса.
        skipped++;
        entries.add(
          BulkEntry(
            title: game.title,
            outcome: BulkOutcome.skipped,
            detail: _l.detailNoSavesYet,
          ),
        );
      } on Object catch (error) {
        failed.add(game.title);
        entries.add(
          BulkEntry(
            title: game.title,
            outcome: BulkOutcome.failed,
            detail: error.toString(),
          ),
        );
      }
    }

    return BulkResult(
      report: BulkReport(isExport: true, entries: entries),
      message: failed.isEmpty
          ? _l.noticeExported(exported, skipped)
          : _l.noticeExportedWithErrors(exported, skipped, failed.join(', ')),
      isError: failed.isNotEmpty,
    );
  }

  /// Разбирает папку с пакетами и раскладывает сохранения по играм —
  /// вторая половина переезда, уже на новом устройстве.
  ///
  /// Пропавшая папка ошибкой не считается — переносить просто нечего.
  /// А вот если чтение сорвалось иначе, исключение уходит наверх: это
  /// провал всей операции, а не исход отдельной игры, и отчёта тут не будет.
  Future<BulkResult> importAll({
    required List<Game> games,
    required String sourceDir,
    required bool overwriteNewer,
    required void Function(SaveSnapshot snapshot) onSnapshot,
  }) async {
    final entries = <BulkEntry>[];
    var applied = 0;
    final unmatched = <String>[];
    final failed = <String>[];
    final conflicted = <String>[];

    final packages = await saves.scanSyncFolder(sourceDir);
    for (final package in packages) {
      final game = matchGame(games, package.snapshot.gameTitle);
      if (game == null) {
        unmatched.add(package.snapshot.gameTitle);
        entries.add(
          BulkEntry(
            title: package.snapshot.gameTitle,
            outcome: BulkOutcome.unmatched,
            detail: _l.detailNoMatchingGame,
          ),
        );
        continue;
      }
      // Пакет мог быть снят раньше, чем игра шла на этом устройстве.
      // Восстановить его — значит откатить прогресс, и резервная копия
      // тут слабое утешение: о ней ещё надо догадаться.
      if (!overwriteNewer) {
        final local = await saves.lastLocalChange(game);
        if (local != null &&
            local.isAfter(package.snapshot.createdAt.add(conflictTolerance))) {
          conflicted.add(game.title);
          entries.add(
            BulkEntry(
              title: game.title,
              outcome: BulkOutcome.conflicted,
              detail: _l.detailNewerHere,
            ),
          );
          continue;
        }
      }

      try {
        final snapshot = await saves.importPackage(package.path, game: game);
        onSnapshot(snapshot);

        final restored = await saves.restoreSnapshot(
          game: game,
          snapshot: snapshot,
        );
        if (restored.backup != null) onSnapshot(restored.backup!);

        if (restored.isComplete) {
          applied++;
          entries.add(
            BulkEntry(title: game.title, outcome: BulkOutcome.applied),
          );
        } else {
          failed.add(game.title);
          entries.add(
            BulkEntry(
              title: game.title,
              outcome: BulkOutcome.failed,
              detail: _l.detailPartialRestore,
            ),
          );
        }
      } on Object catch (error) {
        failed.add(game.title);
        entries.add(
          BulkEntry(
            title: game.title,
            outcome: BulkOutcome.failed,
            detail: error.toString(),
          ),
        );
      }
    }

    return BulkResult(
      report: BulkReport(isExport: false, entries: entries),
      message: <String>[
        _l.noticeApplied(applied),
        if (conflicted.isNotEmpty) _l.noticeNewerHere(conflicted.length),
        if (unmatched.isNotEmpty) _l.noticeNoSuchGame(unmatched.length),
        if (failed.isNotEmpty) _l.noticeFailedCount(failed.length),
      ].join(', '),
      isError: failed.isNotEmpty || unmatched.isNotEmpty,
    );
  }

  /// Идентификаторы игр на разных устройствах не совпадают, поэтому
  /// пакеты сопоставляются по названию.
  static Game? matchGame(List<Game> games, String title) {
    final wanted = title.trim().toLowerCase();
    for (final game in games) {
      if (game.title.trim().toLowerCase() == wanted) return game;
    }
    return null;
  }
}
