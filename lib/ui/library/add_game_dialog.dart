import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../bloc/add_game/add_game_bloc.dart';
import '../../bloc/downloads/downloads_bloc.dart';
import '../../bloc/library/library_bloc.dart';
import '../../bloc/navigation/navigation_bloc.dart';
import '../../l10n/app_localizations.dart';
import 'add/add_game_dialog_view.dart';

/// Окно «Добавить игру» и выбор добавленной: иначе новая игра затеряется
/// среди прочих.
///
/// Навигация берётся до окна, и живость позвавшего не проверяется: клавишу
/// с пустой полки к закрытию окна сменяет сетка с новой игрой, а выбрать
/// её всё равно нужно.
Future<void> showAddGameDialog(BuildContext context) async {
  final nav = context.read<NavigationBloc>();
  final addedId = await showDialog<String>(
    context: context,
    builder: (_) => const AddGameDialog(),
  );
  if (addedId != null) nav.add(GameSelected(addedId));
}

/// Окно «Добавить игру»: папка установки, `.torrent` или magnet-ссылка.
///
/// Проверки ввода, обход папки и ожидание, пока заведённая игра появится в
/// состоянии библиотеки, держит `AddGameBloc`. Здесь остаются контроллеры
/// текста и системные окна выбора файла и папки: и то и другое — ресурсы,
/// а не состояние.
class AddGameDialog extends StatefulWidget {
  const AddGameDialog({super.key});

  @override
  State<AddGameDialog> createState() => _AddGameDialogState();
}

class _AddGameDialogState extends State<AddGameDialog> {
  final _titleController = TextEditingController();
  final _magnetController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _magnetController.dispose();
    super.dispose();
  }

  /// В magnet-ссылке имя лежит в параметре `dn` — подставляем его в
  /// название, пока человек его не написал сам.
  void _onMagnetChanged(BuildContext context, String value) {
    final bloc = context.read<AddGameBloc>();
    bloc.add(AddGameMagnetChanged(value));
    if (_titleController.text.isNotEmpty) return;
    final name = magnetDisplayName(value);
    if (name == null) return;
    _titleController.text = name;
    bloc.add(AddGameTitleChanged(name));
  }

  Future<void> _pickTorrent(BuildContext context) async {
    final bloc = context.read<AddGameBloc>();
    const group = XTypeGroup(label: 'Torrent', extensions: ['torrent']);
    final file = await openFile(acceptedTypeGroups: const [group]);
    if (file == null) return;
    bloc.add(AddGameTorrentPicked(file.path));
    _suggestTitle(bloc, p.basenameWithoutExtension(file.path));
  }

  Future<void> _pickFolder(BuildContext context) async {
    final bloc = context.read<AddGameBloc>();
    final dir = await getDirectoryPath();
    if (dir == null) return;
    bloc.add(AddGameFolderPicked(dir));
    _suggestTitle(bloc, p.basename(dir));
  }

  /// Подставляет название, если человек его ещё не написал: своё он
  /// перебивать не должен.
  void _suggestTitle(AddGameBloc bloc, String name) {
    if (_titleController.text.isNotEmpty) return;
    _titleController.text = name;
    bloc.add(AddGameTitleChanged(name));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AddGameBloc(
        library: context.read<LibraryBloc>(),
        downloads: context.read<DownloadsBloc>(),
        localizations: () => L.of(context),
      ),
      child: BlocConsumer<AddGameBloc, AddGameForm>(
        listenWhen: (before, after) => after.addedId != null,
        listener: (context, form) => Navigator.pop(context, form.addedId),
        builder: (context, form) => AddGameDialogView(
          form: form,
          inputs: (
            magnet: _magnetController,
            title: _titleController,
            onMagnetChanged: (value) => _onMagnetChanged(context, value),
            pickTorrent: () => _pickTorrent(context),
            pickFolder: () => _pickFolder(context),
          ),
        ),
      ),
    );
  }
}
