import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings/settings_bloc.dart';
import '../../input/input_scope.dart';
import '../widgets/liquid_selection.dart';
import '../theme.dart';
import '../widgets/spatial_surface.dart';

import '../../l10n/app_localizations.dart';
import 'shelf.dart';

/// Верхняя строка: полки с числами, поиск и добавление.
class LibraryToolbar extends StatelessWidget {
  const LibraryToolbar({
    super.key,
    required this.shelf,
    required this.counts,
    required this.onShelf,
    required this.searchFocus,
    required this.onQuery,
    required this.onScan,
    required this.onAdd,
    required this.onReturnToGames,
  });

  final Shelf shelf;
  final Map<Shelf, int> counts;
  final ValueChanged<Shelf> onShelf;
  final FocusNode searchFocus;
  final ValueChanged<String> onQuery;
  final VoidCallback onScan;
  final VoidCallback onAdd;
  final VoidCallback onReturnToGames;

  /// Выше этой ширины все три органа встают в строку с просветами.
  static const _wide = 1340.0;

  /// Ниже этой — в строку не влезают вовсе и становятся столбцом.
  static const _narrow = 760.0;

  @override
  Widget build(BuildContext context) {
    final filters = KeyedSubtree(
      key: const ValueKey('library-filter-group'),
      child: ShelfTabs(shelf: shelf, counts: counts, onShelf: onShelf),
    );
    final actions = KeyedSubtree(
      key: const ValueKey('library-actions-group'),
      child: _AddGameButton(onAdd: onAdd, onScan: onScan),
    );
    final search = _search(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
      child: GlassSurface(
        radius: EvaporateTheme.radiusPanel,
        opacity: context.colors.isDark ? 0.72 : 0.84,
        shadow: false,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) => _arrange(
            constraints.maxWidth,
            filters: filters,
            actions: actions,
            search: search,
          ),
        ),
      ),
    );
  }

  /// Расставляет три органа по ширине окна.
  Widget _arrange(
    double width, {
    required Widget filters,
    required Widget actions,
    required Widget search,
  }) {
    if (width >= _wide) {
      return Row(
        children: [filters, const Spacer(), actions, const Spacer(), search],
      );
    }
    if (width >= _narrow) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          filters,
          const SizedBox(width: 6),
          Expanded(child: actions),
          const SizedBox(width: 6),
          search,
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(alignment: Alignment.centerLeft, child: filters),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: search),
        const SizedBox(height: 8),
        Align(alignment: Alignment.center, child: actions),
      ],
    );
  }

  /// Поле поиска.
  ///
  /// Вниз, Escape и Enter возвращают из него в сетку обложек: иначе,
  /// спустившись сюда с клавиатуры, человек в поле и застревал.
  Widget _search(BuildContext context) => SizedBox(
    key: const ValueKey('library-search'),
    width: 144,
    height: 48,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.railBackground.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(EvaporateTheme.radiusPanel),
        border: Border.all(
          color: context.colors.textPrimary.withValues(alpha: 0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 3, right: 3, bottom: 0, left: 3),
        child: Actions(
          actions: {
            ReturnToLibraryIntent: CallbackAction<ReturnToLibraryIntent>(
              onInvoke: (_) {
                onReturnToGames();
                return null;
              },
            ),
          },
          child: Shortcuts(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.arrowDown):
                  ReturnToLibraryIntent(),
              SingleActivator(LogicalKeyboardKey.escape):
                  ReturnToLibraryIntent(),
              SingleActivator(LogicalKeyboardKey.enter):
                  ReturnToLibraryIntent(),
              SingleActivator(LogicalKeyboardKey.numpadEnter):
                  ReturnToLibraryIntent(),
            },
            child: TextField(
              focusNode: searchFocus,
              onChanged: onQuery,
              onSubmitted: (_) => onReturnToGames(),
              decoration: InputDecoration(
                hintText: L.of(context).searchHint,
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: false,
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// «Добавить игру» — одна клавиша с меню на два способа.
///
/// Прежде рядом стояли две равные по виду клавиши, «Найти установленные
/// игры» и «Добавить игру», и обе делали одно: пополняли библиотеку.
/// Выбирать между ними приходилось до того, как станет понятно, чем они
/// различаются. Теперь выбор — внутри одного действия, и в панели у него
/// одно место.
///
/// Меню, а не расщеплённая клавиша: у расщеплённой две области нажатия и
/// две остановки фокуса, а сюда ходят и с клавиатуры, и с геймпада.
class _AddGameButton extends StatelessWidget {
  const _AddGameButton({required this.onAdd, required this.onScan});

  final VoidCallback onAdd;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return MenuAnchor(
      builder: (context, controller, _) => OutlinedButton.icon(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.only(left: 12, right: 8),
        ),
        icon: const Icon(Icons.add, size: 19),
        // Подпись гибкая: в узком окне на неё остаётся шестьдесят точек, и
        // жёсткий ряд из слова и уголка рисовал там полосатую ленту
        // переполнения. Штатная подпись клавиши переносится по словам —
        // этот ряд должен уметь то же.
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(l.addGame)),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
      menuChildren: [
        MenuItemButton(
          onPressed: onAdd,
          leadingIcon: const Icon(Icons.link, size: 18),
          child: Text(l.addGameSource),
        ),
        MenuItemButton(
          onPressed: onScan,
          leadingIcon: const Icon(Icons.folder_open_outlined, size: 18),
          child: Text(l.findInstalledGames),
        ),
      ],
    );
  }
}

class ShelfTabs extends StatefulWidget {
  const ShelfTabs({
    super.key,
    required this.shelf,
    required this.counts,
    required this.onShelf,
  });
  final Shelf shelf;
  final Map<Shelf, int> counts;
  final ValueChanged<Shelf> onShelf;

  @override
  State<ShelfTabs> createState() => _ShelfTabsState();
}

class _ShelfTabsState extends State<ShelfTabs> {
  final _targets = {for (final shelf in Shelf.values) shelf: GlobalKey()};

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.railBackground.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(EvaporateTheme.radiusPanel),
      border: Border.all(
        color: context.colors.textPrimary.withValues(alpha: 0.1),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(3),
      child: LiquidSelection(
        key: const ValueKey('shelf-liquid'),
        targetKey: () => _targets[widget.shelf],
        color: context.colors.selection,
        radius: EvaporateTheme.radiusControl,
        enabled: context.select<SettingsBloc, bool>(
          (b) => b.state.libraryEffects && b.state.liquidSelectionEnabled,
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final value in Shelf.values)
              ShelfButton(
                key: _targets[value],
                label: _label(L.of(context), value),
                count: widget.counts[value] ?? 0,
                active: value == widget.shelf,
                onTap: () => widget.onShelf(value),
              ),
          ],
        ),
      ),
    ),
  );

  static String _label(L l, Shelf shelf) => switch (shelf) {
    Shelf.all => l.tabAll,
    Shelf.installed => l.tabInstalled,
    Shelf.notInstalled => l.tabNotInstalled,
  };
}

/// Полка с числом рядом — как вкладки в библиотеке Steam.
class ShelfButton extends StatelessWidget {
  const ShelfButton({
    super.key,
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: AppColors.transparent,
          foregroundColor: active ? colors.onSelection : colors.textSecondary,
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(EvaporateTheme.radiusControl),
          ),
        ),
        child: LiquidSelectionInk(
          normalColor: colors.textSecondary,
          selectedColor: colors.onSelection,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '$count',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
