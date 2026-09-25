import 'package:flutter/material.dart';

import '../../bloc/library/library_bloc.dart';
import '../../bloc/saves/saves_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../models/game.dart';
import '../../models/save_snapshot.dart';
import '../theme.dart';
import '../widgets/section_heading.dart';
import '../widgets/watch_while_shown.dart';
import 'bulk_transfer_card.dart';
import 'saves_readout.dart';
import 'sliver_side_by_side.dart';
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
///
/// Страница собрана сливерами: хронология бывает в сотни строк, и строить
/// их надо по мере прокрутки, а не все разом.
class SavesPage extends StatelessWidget {
  const SavesPage({super.key});

  /// С этой ширины действия и хронология встают рядом.
  static const _twoColumns = 1080.0;

  /// Ширина колонки действий рядом с хронологией.
  static const _actionsWidth = 430.0;

  @override
  Widget build(BuildContext context) {
    final games = context
        .selectWhileShown<LibraryBloc, LibraryState, List<Game>>(
          (state) => state.games,
        );
    final snapshots = context
        .selectWhileShown<
          SavesBloc,
          SavesState,
          Map<String, List<SaveSnapshot>>
        >((state) => state.snapshots);

    final entries = SavesState.entriesOf(games, snapshots);
    final configured = games.where((g) => g.saveProfile.isConfigured).length;

    // Абзац про то, что такое .evsave, здесь не стоит: то же, только по
    // делу, написано в самих карточках, а три объяснения подряд человек не
    // читает ни одного.
    final overview = SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            label: L.of(context).sectionSavesLabel,
            semanticsLabel: L.of(context).saves,
            padding: const EdgeInsets.only(bottom: EvaporateSpacing.section),
          ),
          SavesReadout(entries: entries, configured: configured),
          const SizedBox(height: EvaporateSpacing.card),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, box) => CustomScrollView(
        clipBehavior: Clip.none, // и под стеклом полос: см. `EvAppShell`
        slivers: [
          SliverPadding(
            padding: EvaporateLayout.pagePaddingFor(box.maxWidth),
            sliver: SliverMainAxisGroup(
              slivers: [
                overview,
                SliverSideBySide(
                  wide: box.maxWidth >= _twoColumns,
                  leftWidth: _actionsWidth,
                  gap: 18,
                  left: const SliverToBoxAdapter(
                    child: Column(
                      children: [BulkTransferCard(), SyncFolderCard()],
                    ),
                  ),
                  right: SnapshotHistory(entries: entries),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
