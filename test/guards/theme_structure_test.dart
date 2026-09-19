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
  // Типографика картинки, а не роль: надписи поверх обложки и крупного
  // кадра, знак приложения в верхней панели.
  'lib/ui/library/detail/detail_cover.dart: 1',
  'lib/ui/library/cover/cover_title_plate.dart: 1',
  'lib/ui/library/featured/featured_compact_bar.dart: 1',
  'lib/ui/library/featured/featured_poster.dart: 1',
  'lib/ui/shell/top_bar_brand.dart: 1',
  // Ещё не сведена клавиша обоймы: это метка без моно, и перевод на
  // `label` заметно меняет облик — решается отдельно.
  'lib/ui/shell/navigation_key.dart: 1',
];

const _durations = [
  'lib/ui/widgets/animated_progress.dart: 1',
  'lib/ui/widgets/liquid_selection.dart: 1',
  'lib/ui/widgets/rise_in.dart: 1',
];

const _radii = <String>[];

const _alphas = [
  'lib/ui/downloads/download_chart.dart: 2',
  'lib/ui/feedback/snack.dart: 1',
  'lib/ui/library/featured/featured_actions.dart: 1',
  'lib/ui/library/featured/playtime_readout.dart: 1',
  'lib/ui/library/effects/foil/foil_surface.dart: 2',
  'lib/ui/library/effects/library_atmosphere.dart: 2',
  'lib/ui/library/effects/portal/portal_atlas.dart: 1',
  'lib/ui/widgets/progress_hatching.dart: 1',
  'lib/ui/widgets/pulse_dot.dart: 2',
];
