import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/library/library_bloc.dart';
import '../../bloc/saves/saves_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../theme.dart';
import '../widgets/section_heading.dart';
import 'bulk_transfer_card.dart';
import 'saves_readout.dart';
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

    final entries = saves.entriesFor(library.games);
    final configured = library.games
        .where((g) => g.saveProfile.isConfigured)
        .length;

    const actions = Column(children: [BulkTransferCard(), SyncFolderCard()]);
    final history = SnapshotsCard(entries: entries);

    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 1080;
        return ListView(
          padding: EvaporateLayout.pagePadding,
          children: [
            Center(
              // Шире некуда: строка описания за этой границей перестаёт
              // читаться, а карточки превращаются в полосы.
              child: ConstrainedBox(
                constraints: EvaporateLayout.contentConstraints,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Абзац про то, что такое .evsave, здесь не стоит: то
                    // же, только по делу, написано в самих карточках, а три
                    // объяснения подряд человек не читает ни одного.
                    SectionHeading(
                      label: L.of(context).conceptSavesLabel,
                      semanticsLabel: L.of(context).saves,
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 20),
                    SavesReadout(entries: entries, configured: configured),
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
}
