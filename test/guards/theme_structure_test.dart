import 'package:evaporate/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/guards.dart';

/// Облик задаёт тема, а не виджет.
///
/// Разбросанные по виджетам числа расходятся сами собой — тот же довод,
/// которым в `motion.dart` обоснованы токены длительностей, — а ветвление
/// по схеме внутри виджета означает, что третья схема потребовала бы
/// правки каждого из них. Вне файлов темы не должно быть:
///
/// - `isDark` — различие схем записывается данными темы, а не кодом;
/// - `fontSize:` — кегль берётся из ролей типографики;
/// - `Duration(milliseconds:` — длительность берётся из `context.motion`;
/// - `BorderRadius.circular(<число>)` — радиус берётся из `EvaporateTheme`;
/// - поле страницы 28, предельная ширина 1340 и подпись настройки 220 —
///   из `EvaporateLayout`;
/// - `withValues(alpha: <число>)` — прозрачность берётся ступенью
///   `EvaporateAlpha`.
///
/// Списки ниже — известные нарушители на момент введения правила (этап 2
/// в `TODO.md`), с числом вхождений. Пополнять их нельзя; вынесенное —
/// вычёркивать или уменьшать число.
void main() {
  bool isThemeFile(String path) =>
      path.startsWith('lib/ui/theme/') || path == 'lib/ui/theme.dart';

  final sources = dartSources('lib/ui', skip: isThemeFile);

  Iterable<String> count(RegExp pattern) sync* {
    for (final file in sources) {
      final n = pattern.allMatches(file.code).length;
      if (n > 0) yield '${file.path}: $n';
    }
  }

  test('isDark не ветвит виджеты', () {
    expectRatchet(
      found: count(RegExp(r'\bisDark\b')),
      known: _isDark,
      rule: 'различие схем — поле темы компонента, а не ветвление в виджете',
    );
  });

  test('кегль не задаётся по месту', () {
    expectRatchet(
      found: count(RegExp(r'\bfontSize\s*:')),
      known: _fontSize,
      rule: 'кегль — роль типографики темы',
    );
  });

  test('длительности не задаются числом по месту', () {
    expectRatchet(
      found: count(RegExp(r'Duration\(\s*milliseconds\s*:')),
      known: _durations,
      rule: 'длительность — токен context.motion',
    );
  });

  test('радиусы не задаются числом по месту', () {
    expectRatchet(
      found: count(RegExp(r'BorderRadius\.circular\(\s*\d')),
      known: _radii,
      rule: 'радиус — токен EvaporateTheme',
    );
  });

  // Ловит только числа, которые уже были токенами: 28 бывает и отступом
  // сетки, и размытием, и запрет «любого 28» бил бы мимо.
  test('размеры раскладки не задаются числом по месту', () {
    expectRatchet(
      found: count(
        RegExp(r'fromLTRB\(\s*28\b|maxWidth:\s*1340\b|width:\s*220\b'),
      ),
      known: const [],
      rule: 'поля, ширины и высоты полос — постоянные EvaporateLayout',
    );
  });

  // В списке — художники, у которых прозрачность — часть расчёта
  // анимации (фольга, искры, пульс, график), и подписи поверх обложки.
  test('прозрачность не задаётся числом по месту', () {
    expectRatchet(
      found: count(RegExp(r'withValues\(\s*alpha:\s*[\d.]')),
      known: _alphas,
      rule: 'прозрачность — ступень EvaporateAlpha',
    );
  });

  // Расширение, которое есть у одной схемы и нет у другой, молча отдаёт
  // виджету запасное значение, а плавная смена схемы смешивает его с
  // пустотой. Проверяем и сами схемы, и их смесь посередине перехода.
  test('у обеих схем один набор расширений, и он переживает смену', () {
    final dark = EvaporateTheme.dark();
    final light = EvaporateTheme.light();

    expect(dark.extensions.keys.toSet(), light.extensions.keys.toSet());
    final mixed = ThemeData.lerp(dark, light, 0.5);
    expect(mixed.extensions.keys.toSet(), dark.extensions.keys.toSet());
    for (final extension in mixed.extensions.values) {
      expect(
        extension.runtimeType,
        dark.extensions[extension.type]!.runtimeType,
      );
    }
  });
}

const _isDark = <String>[];

const _fontSize = [
  'lib/ui/downloads/download_activity.dart: 3',
  'lib/ui/downloads/engine_status.dart: 1',
  'lib/ui/downloads/queue_column.dart: 2',
  'lib/ui/downloads/task_card.dart: 1',
  'lib/ui/library/detail/action_panel.dart: 1',
  'lib/ui/library/detail/detail_cover.dart: 2',
  'lib/ui/library/detail/detail_header.dart: 1',
  'lib/ui/library/detail/rating_row.dart: 4',
  'lib/ui/library/drop_overlay.dart: 1',
  'lib/ui/library/featured_game.dart: 3',
  'lib/ui/library/game_cover.dart: 2',
  'lib/ui/library/saves/restore_dialog.dart: 3',
  'lib/ui/library/saves/rule_dialog.dart: 1',
  'lib/ui/library/saves/save_tag.dart: 1',
  'lib/ui/library/saves/suggestions_dialog.dart: 1',
  'lib/ui/library/saves/watched_folders.dart: 2',
  'lib/ui/library/scan_folder_dialog.dart: 3',
  'lib/ui/library/toolbar.dart: 2',
  'lib/ui/saves/bulk_transfer_card.dart: 1',
  'lib/ui/saves/snapshot_history.dart: 2',
  'lib/ui/settings/gamepad_settings.dart: 1',
  'lib/ui/settings/log_card.dart: 1',
  'lib/ui/shell/navigation.dart: 2',
  'lib/ui/shell/top_bar.dart: 1',
  'lib/ui/widgets/button_hints.dart: 2',
  'lib/ui/widgets/common.dart: 5',
];

const _durations = [
  'lib/ui/widgets/animated_progress.dart: 1',
  'lib/ui/widgets/liquid_selection.dart: 1',
  'lib/ui/widgets/rise_in.dart: 1',
];

const _radii = <String>[];

const _alphas = [
  'lib/ui/downloads/download_activity.dart: 2',
  'lib/ui/library/featured_game.dart: 2',
  'lib/ui/library/foil_card.dart: 2',
  'lib/ui/library/library_atmosphere.dart: 2',
  'lib/ui/library/portal_sparks.dart: 1',
  'lib/ui/widgets/animated_progress.dart: 1',
  'lib/ui/widgets/common.dart: 1',
  'lib/ui/widgets/pulse_dot.dart: 2',
];
