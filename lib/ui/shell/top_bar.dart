import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';

import '../../bloc/navigation/navigation_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../theme.dart';
import '../widgets/app_mark.dart';
import '../widgets/window_frame.dart';
import 'navigation.dart';

/// Верхняя рейка: бренд и действия стоят по краям, а разделы — ровно по
/// центру доступной ширины. В узком окне разделы переезжают вниз.
class ConceptTopBar extends StatelessWidget {
  const ConceptTopBar({super.key, required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 64,
    child: Stack(
      alignment: Alignment.center,
      children: [
        // Подложка рейки тянет окно: своей полосы заголовка у приложения
        // больше нет, и двигать окно человеку иначе нечем. Лежит ниже
        // всего остального, поэтому клавиши и обойма забирают нажатия себе,
        // а знак, название и просветы между ними — тянут.
        const _WindowDragArea(),
        Row(
          children: [
            // Знак и название — не органы управления: нажатие проходит сквозь
            // них к подложке, которая тянет окно. Без этого текст забирал бы
            // нажатие себе (RenderParagraph отвечает на попадание), и окно
            // не тянулось бы за собственное имя — самое очевидное место,
            // чтобы взяться.
            IgnorePointer(child: _brand(context)),
            if (compact) ...[
              // В узком окне разделы остаются в рейке, а не уезжают вниз:
              // обойма сама прячет подписи и сжимается по месту. Прежде она
              // переезжала под содержимое и налезала на подсказки
              // управления в нижней строке.
              const SizedBox(width: 10),
              const Expanded(child: Center(child: ConceptNavigation())),
              const SizedBox(width: 10),
            ] else
              const Spacer(),
            ..._actions(context),
          ],
        ),
        // В широком окне обойма стоит ровно по центру всей рейки, а не
        // между знаком и действиями: для этого она и лежит в Stack.
        if (!compact) const ConceptNavigation(),
      ],
    ),
  );

  /// Знак и название приложения.
  Widget _brand(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Знак в собственной оправе с волосяным кантом: на чернильном фоне
        // без канта он выглядит вырезанным из другой картинки.
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            border: Border.all(color: colors.primary.withValues(alpha: 0.42)),
            borderRadius: BorderRadius.circular(EvaporateTheme.radiusControl),
          ),
          child: const AppMark(size: 30),
        ),
        if (!compact) ...[
          const SizedBox(width: 11),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'EVAPORATE',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontFamily: EvaporateTheme.monoFontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 4),
              // Короткий золотой штрих под словом — подпись на корпусе,
              // а не украшение: он же задаёт фирменный цвет всей рейке.
              Container(width: 26, height: 2, color: colors.primary),
            ],
          ),
        ],
      ],
    );
  }

  /// Поиск, смена схемы и выход.
  List<Widget> _actions(BuildContext context) {
    final settings = context.watch<SettingsBloc>().state;
    final mode = settings.themeMode;
    return [
      TopAction(
        tooltip: L.of(context).searchHint,
        icon: Icons.search_rounded,
        onPressed: () =>
            context.read<NavigationBloc>().add(const SearchFocusRequested()),
      ),
      const SizedBox(width: 7),
      TopAction(
        // Клавиша перебирает все три состояния, а не два: прежде она
        // переключала тёмное со светлым и молча съедала «как в системе» —
        // вернуть его можно было только в настройках, куда за этим никто
        // не идёт.
        tooltip: _themeActionLabel(context, _nextTheme(mode)),
        icon: _themeIcon(mode),
        onPressed: () => context.read<SettingsBloc>().add(
          SettingsChanged(settings.copyWith(themeMode: _nextTheme(mode))),
        ),
      ),
      const SizedBox(width: 7),
      ..._windowActions(context),
      TopAction(
        key: const ValueKey('rail-quit'),
        tooltip: L.of(context).quitApp,
        hiddenLabel: L.of(context).quitApp,
        icon: Icons.power_settings_new_rounded,
        danger: true,
        onPressed: () => unawaited(windowManager.close()),
      ),
    ];
  }

  /// Свернуть и развернуть.
  ///
  /// Появляются, только когда рамку рисуем мы сами: с рамкой ОС эти клавиши
  /// у окна уже есть, и вторых ему не нужно.
  List<Widget> _windowActions(BuildContext context) {
    final control = WindowControl.maybeOf(context);
    if (control == null) return const [];

    final l = L.of(context);
    return [
      TopAction(
        key: const ValueKey('rail-minimize'),
        tooltip: l.minimizeWindow,
        icon: Icons.remove,
        onPressed: () =>
            unawaited(runWindowAction(context, windowManager.minimize)),
      ),
      const SizedBox(width: 7),
      TopAction(
        key: const ValueKey('rail-maximize'),
        tooltip: control.expanded ? l.restoreWindow : l.maximizeWindow,
        icon: control.expanded ? Icons.filter_none : Icons.crop_square,
        onPressed: () => unawaited(control.toggleSize()),
      ),
      const SizedBox(width: 7),
    ];
  }

  /// Порядок перебора: из системного — в светлое, дальше в тёмное и назад в
  /// системное. Подпись на клавише обещает то, что получится после нажатия.
  static ThemeMode _nextTheme(ThemeMode mode) => switch (mode) {
    ThemeMode.system => ThemeMode.light,
    ThemeMode.light => ThemeMode.dark,
    ThemeMode.dark => ThemeMode.system,
  };

  static IconData _themeIcon(ThemeMode mode) => switch (mode) {
    ThemeMode.system => Icons.brightness_auto_outlined,
    ThemeMode.light => Icons.light_mode_outlined,
    ThemeMode.dark => Icons.dark_mode_outlined,
  };

  static String _themeActionLabel(BuildContext context, ThemeMode mode) =>
      switch (mode) {
        ThemeMode.system => L.of(context).systemThemeAction,
        ThemeMode.light => L.of(context).lightThemeAction,
        ThemeMode.dark => L.of(context).darkThemeAction,
      };
}

/// Клавиша верхней рейки. Под курсором подсвечивается и чуть поднимается —
/// на строке из одинаковых квадратов это единственный способ показать, где
/// именно сейчас рука.
class TopAction extends StatefulWidget {
  const TopAction({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.hiddenLabel,
    this.danger = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final String? hiddenLabel;

  /// Действие, которое закрывает приложение. Подсвечивается тревожным
  /// цветом только под курсором: постоянно красная кнопка выхода в углу
  /// читалась бы как поломка.
  final bool danger;

  @override
  State<TopAction> createState() => _TopActionState();
}

class _TopActionState extends State<TopAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = widget.danger ? colors.danger : colors.primary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: context.motion.fast,
        curve: EvaporateMotion.ease,
        transform: Matrix4.translationValues(0, _hovered ? -1 : 0, 0),
        child: IconButton(
          tooltip: widget.tooltip,
          onPressed: widget.onPressed,
          icon: Stack(
            alignment: Alignment.center,
            children: [
              Icon(widget.icon, size: 18),
              if (widget.hiddenLabel case final label?)
                SizedBox.shrink(child: ExcludeSemantics(child: Text(label))),
            ],
          ),
          style: IconButton.styleFrom(
            minimumSize: const Size(38, 38),
            backgroundColor: _hovered
                ? colors.surfaceHigh
                : colors.surface.withValues(alpha: 0.5),
            foregroundColor: _hovered ? accent : colors.textSecondary,
            side: BorderSide(
              color: _hovered ? accent.withValues(alpha: 0.6) : colors.outline,
            ),
          ),
        ),
      ),
    );
  }
}

/// Подложка, за которую таскают окно. Двойное нажатие по ней разворачивает
/// окно — так же, как по заголовку обычного окна системы.
///
/// Пуста, если своей рамки нет: окном тогда распоряжается система, и
/// перехватывать её жесты нельзя.
class _WindowDragArea extends StatelessWidget {
  const _WindowDragArea();

  @override
  Widget build(BuildContext context) {
    final control = WindowControl.maybeOf(context);
    if (control == null) return const SizedBox.shrink();

    return GestureDetector(
      key: const ValueKey('window-drag-region'),
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) =>
          unawaited(runWindowAction(context, windowManager.startDragging)),
      onDoubleTap: () => unawaited(control.toggleSize()),
      child: const SizedBox.expand(),
    );
  }
}
