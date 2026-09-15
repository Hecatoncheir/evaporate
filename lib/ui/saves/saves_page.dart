import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/library/library_bloc.dart';
import '../../bloc/saves/saves_bloc.dart';
import '../../core/format.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/readout_panel.dart';
import '../widgets/section_heading.dart';
import 'bulk_transfer_card.dart';
import 'snapshot_history.dart';
import 'sync_folder_card.dart';

/// Общий экран переноса сохранений: состояние хранилища, папка синхронизации,
/// пакеты с других устройств и все снимки библиотеки в одном списке.
///
/// Читается сверху вниз как прибор: сначала **показания** — сколько снимков,
/// сколько занято, когда снимали последний раз, — и только потом органы
/// управления. Раньше те же числа были рассыпаны по углам карточек, и
/// ответа на главный вопрос «всё ли у меня сохранено» экран не давал.
///
/// Действия и хронология разведены по колонкам: выгрузка и папка
/// синхронизации — слева, список снимков — справа. В одну колонку они
/// выстраиваются только в узком окне: растянутый на всю ширину список из
/// трёх строк выглядит пустым экраном.
class SavesPage extends StatelessWidget {
  const SavesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryBloc>().state;
    final saves = context.watch<SavesBloc>().state;

    final entries = _allSnapshots(library, saves);
    final stored = entries.fold<int>(0, (sum, e) => sum + e.$2.sizeBytes);
    final configured = library.games
        .where((g) => g.saveProfile.isConfigured)
        .length;

    const actions = Column(children: [BulkTransferCard(), SyncFolderCard()]);
    final history = SnapshotsCard(entries: entries);

    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 1080;
        return ListView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
          children: [
            Center(
              // Шире некуда: строка описания за этой границей перестаёт
              // читаться, а карточки превращаются в полосы.
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1340),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Heading(),
                    const SizedBox(height: 20),
                    _readout(context, entries, stored, configured),
                    const SizedBox(height: 18),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(width: 430, child: actions),
                          const SizedBox(width: 18),
                          Expanded(child: history),
                        ],
                      )
                    else ...[
                      actions,
                      history,
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Все снимки библиотеки, свежие сверху.
  ///
  /// Снимки лежат по играм, а экран показывает их одним списком: это ответ
  /// на вопрос «что у меня вообще сохранено», а не «что сохранено у этой
  /// игры» — на него отвечает карточка на странице самой игры.
  List<SnapshotEntry> _allSnapshots(LibraryState library, SavesState saves) {
    final entries = <SnapshotEntry>[];
    for (final game in library.games) {
      for (final snapshot in saves.snapshotsFor(game.id)) {
        entries.add((game, snapshot));
      }
    }
    entries.sort((a, b) => b.$2.createdAt.compareTo(a.$2.createdAt));
    return entries;
  }

  /// Показания хранилища: что спрашивают в первую очередь.
  Widget _readout(
    BuildContext context,
    List<SnapshotEntry> entries,
    int stored,
    int configured,
  ) {
    final l = L.of(context);
    final last = entries.isEmpty ? null : entries.first.$2.createdAt;
    return ReadoutPanel(
      cells: [
        ReadoutCell(label: l.savesStatSnapshots, value: '${entries.length}'),
        ReadoutCell(label: l.savesStatSize, value: formatBytes(stored)),
        ReadoutCell(label: l.savesStatGames, value: '$configured'),
        ReadoutCell(
          label: l.savesStatLast,
          value: last == null ? l.savesStatNever : formatDateTime(last),
          // Дата длиннее числа и в тот же кегль не влезает.
          compact: true,
          dim: last == null,
        ),
      ],
    );
  }
}

/// Подпись раздела.
///
/// Абзац про то, что такое `.evsave`, отсюда убран: то же самое, только по
/// делу, написано в самих карточках — «Перенос всей библиотеки» и «Папка
/// синхронизации». Три объяснения подряд на одном экране человек не читает
/// ни одного.
class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) => SectionHeading(
    label: L.of(context).conceptSavesLabel,
    semanticsLabel: L.of(context).saves,
    padding: EdgeInsets.zero,
  );
}
