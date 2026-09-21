import 'package:path/path.dart' as p;

import '../../core/format.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_ru.dart';
import '../../models/bulk_report.dart';
import '../../models/game.dart';
import '../../models/save_snapshot.dart';
import 'save_manager.dart';
import 'title_match.dart';

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
    for (final game in games) {
      entries.add(await _exportOne(game, destinationDir, onSnapshot));
    }

    final report = BulkReport(isExport: true, entries: entries);
    final failed = _titles(report, BulkOutcome.failed);
    return BulkResult(
      report: report,
      message: failed.isEmpty
          ? _l.noticeExported(
              report.count(BulkOutcome.applied),
              report.count(BulkOutcome.skipped),
            )
          : _l.noticeExportedWithErrors(
              report.count(BulkOutcome.applied),
              report.count(BulkOutcome.skipped),
              failed.join(', '),
            ),
      isError: failed.isNotEmpty,
    );
  }

  /// Судьба одной игры при выгрузке.
  ///
  /// Исход возвращается записью отчёта, а не складывается в счётчики по
  /// дороге: счёт потом снимет сам отчёт (`BulkReport.count`), и разойтись
  /// им негде.
  Future<BulkEntry> _exportOne(
    Game game,
    String destinationDir,
    void Function(SaveSnapshot snapshot) onSnapshot,
  ) async {
    if (game.saveProfile.rulesForCurrentPlatform.isEmpty) {
      return BulkEntry(
        title: game.title,
        outcome: BulkOutcome.skipped,
        detail: _l.detailNoSavePaths,
      );
    }
    try {
      final snapshot = await saves.createSnapshot(game);
      onSnapshot(snapshot);
      await saves.exportSnapshot(
        snapshot,
        p.join(
          destinationDir,
          '${safeFileName(game.title)}-${safeFileName(game.id)}'
          '${SaveSnapshot.fileExtension}',
        ),
      );
      return BulkEntry(title: game.title, outcome: BulkOutcome.applied);
    } on SaveNothingFoundException {
      // Пути заданы, но файлов ещё нет — это не ошибка переноса.
      return BulkEntry(
        title: game.title,
        outcome: BulkOutcome.skipped,
        detail: _l.detailNoSavesYet,
      );
    } on Object catch (error) {
      return BulkEntry(
        title: game.title,
        outcome: BulkOutcome.failed,
        detail: error.toString(),
      );
    }
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
    // scanSyncFolder сортирует пакеты от новых к старым, и для одной игры
    // применяется только самый свежий: следующий откатил бы его.
    final seen = <String>{};

    final packages = await saves.scanSyncFolder(
      sourceDir,
      onSkipped: (path, error) => entries.add(
        BulkEntry(
          title: p.basename(path),
          outcome: BulkOutcome.failed,
          detail: error is SaveException ? error.message : '$error',
        ),
      ),
    );
    for (final package in packages) {
      entries.add(
        await _importOne(
          package,
          games: games,
          seen: seen,
          overwriteNewer: overwriteNewer,
          onSnapshot: onSnapshot,
        ),
      );
    }

    final report = BulkReport(isExport: false, entries: entries);
    final failed = report.count(BulkOutcome.failed);
    final unmatched = report.count(BulkOutcome.unmatched);
    final conflicted = report.count(BulkOutcome.conflicted);
    return BulkResult(
      report: report,
      message: <String>[
        _l.noticeApplied(report.count(BulkOutcome.applied)),
        if (conflicted > 0) _l.noticeNewerHere(conflicted),
        if (unmatched > 0) _l.noticeNoSuchGame(unmatched),
        if (failed > 0) _l.noticeFailedCount(failed),
      ].join(', '),
      isError: failed > 0 || unmatched > 0,
    );
  }

  /// Судьба одного пакета: кому он принадлежит и можно ли его применять.
  ///
  /// Все отказы — ранними выходами: они и есть исход, а не ступень к нему.
  Future<BulkEntry> _importOne(
    SavePackageInfo package, {
    required List<Game> games,
    required Set<String> seen,
    required bool overwriteNewer,
    required void Function(SaveSnapshot snapshot) onSnapshot,
  }) async {
    final game = matchGame(games, package.snapshot.gameTitle);
    if (game == null) {
      return BulkEntry(
        title: package.snapshot.gameTitle,
        outcome: BulkOutcome.unmatched,
        detail: _l.detailNoMatchingGame,
      );
    }
    if (!seen.add(game.id)) {
      return BulkEntry(
        title: game.title,
        outcome: BulkOutcome.skipped,
        detail: _l.detailNewerPackage,
      );
    }
    if (!overwriteNewer && await _localIsNewer(game, package)) {
      return BulkEntry(
        title: game.title,
        outcome: BulkOutcome.conflicted,
        detail: _l.detailNewerHere,
      );
    }
    return _restoreOne(game, package, onSnapshot);
  }

  /// Успели ли здесь поиграть после того, как сняли пакет.
  ///
  /// Восстановить такой пакет — значит откатить прогресс, и резервная
  /// копия тут слабое утешение: о ней ещё надо догадаться.
  Future<bool> _localIsNewer(Game game, SavePackageInfo package) async {
    final local = await saves.lastLocalChange(game);
    if (local == null) return false;
    return local.isAfter(package.snapshot.createdAt.add(conflictTolerance));
  }

  /// Заводит пакет у себя и раскладывает его сохранения по местам.
  Future<BulkEntry> _restoreOne(
    Game game,
    SavePackageInfo package,
    void Function(SaveSnapshot snapshot) onSnapshot,
  ) async {
    try {
      final snapshot = await saves.importPackage(package.path, game: game);
      onSnapshot(snapshot);

      final restored = await saves.restoreSnapshot(
        game: game,
        snapshot: snapshot,
        onBackup: (backup) async => onSnapshot(backup),
      );
      if (restored.isComplete) {
        return BulkEntry(title: game.title, outcome: BulkOutcome.applied);
      }
      return BulkEntry(
        title: game.title,
        outcome: BulkOutcome.failed,
        detail: _l.detailPartialRestore,
      );
    } on Object catch (error) {
      return BulkEntry(
        title: game.title,
        outcome: BulkOutcome.failed,
        detail: error.toString(),
      );
    }
  }

  /// Названия игр с таким исходом — их называют человеку поимённо.
  static List<String> _titles(BulkReport report, BulkOutcome outcome) => [
    for (final entry in report.entries)
      if (entry.outcome == outcome) entry.title,
  ];

  /// Идентификаторы игр на разных устройствах не совпадают, поэтому
  /// пакеты сопоставляются по названию.
  static Game? matchGame(List<Game> games, String title) {
    Game? match;
    for (final game in games) {
      if (!sameGameTitle(game.title, title)) continue;
      if (match != null) return null;
      match = game;
    }
    return match;
  }
}
