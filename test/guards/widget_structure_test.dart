import 'package:flutter_test/flutter_test.dart';

import '../support/guards.dart';
import '../support/widget_structure.dart';

/// Один файл — один публичный виджет; ни приватных виджетов, ни методов,
/// собирающих виджеты.
///
/// Приватный виджет и метод-виджет прячут часть экрана там, где её не
/// найти по имени, не переиспользовать и не проверить отдельно; метод к
/// тому же лишён своего `Element`: у него нет границы перестроения и
/// `const`, и в инспекторе его не видно. Законны `_FooState` — это идиома
/// Flutter, а не виджет, — и `build`.
///
/// Списки ниже — известные нарушители на момент введения правила (см.
/// этап 3 в `TODO.md`). Пополнять их нельзя; вынесенное — вычёркивать.
void main() {
  final sources = dartSources('lib/ui');

  test('новых приватных виджетов нет', () {
    expectRatchet(
      found: sources.expand(privateWidgets),
      known: _privateWidgets,
      rule: 'приватный виджет — в свой файл под публичным именем',
    );
  });

  test('новых методов, собирающих виджеты, нет', () {
    expectRatchet(
      found: sources.expand(widgetFunctions),
      known: _widgetFunctions,
      rule: 'метод-виджет — в класс виджета своим файлом',
    );
  });

  // Число после двоеточия — сколько виджетов в файле сейчас. Вынесли
  // один — число в списке уменьшается, вынесли все, кроме одного, —
  // запись уходит.
  test('новых файлов с несколькими виджетами нет', () {
    expectRatchet(
      found: sources.expand(crowdedFiles),
      known: _crowdedFiles,
      rule: 'один файл — один виджет',
    );
  });
}

const _privateWidgets = <String>[];

const _widgetFunctions = <String>[];

const _crowdedFiles = <String>[];
