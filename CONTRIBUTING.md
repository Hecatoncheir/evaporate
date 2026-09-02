# Как поучаствовать

*[In English](#contributing)*

Отчёт об ошибке, правка перевода, замечание к формулировке — всё уместно.
Ниже то, что стоит знать до отправки правки.

## С чего начать

```bash
flutter pub get
flutter test
```

Тестам не нужны ни сеть, ни геймпад, ни собранное приложение. Часть
пропускается там, где проверять нечем: работа с реестром и ветки реестра из
базы путей — вне Windows. Это нормально, красным они не горят.

Для сборки под Linux нужен `libayatana-appindicator3-dev` — без него не
соберётся значок в трее. Для сборки под macOS — полный Xcode, не только
Command Line Tools.

## Что проверяется в CI

```bash
dart format --set-exit-if-changed lib test tool
flutter analyze
flutter test
```

**Анализатор считает провалом и подсказки, не только ошибки.** Смотрите весь
его вывод, а не отфильтрованный по слову `error`, — иначе правка доедет до CI
и вернётся оттуда красной.

Сборки трёх платформ идут только на теге `v*`. Проверить, что проект
собирается, не выпуская версию, можно ручным запуском прогона.

## Строки интерфейса

Все видимые строки живут в `lib/l10n/app_ru.arb` и `app_en.arb`. Русский —
исходный, английский обязателен: тест сверяет наборы ключей и следит, чтобы
подстановки не разошлись.

Отдельный тест обходит `lib/ui` и падает на любой строке с кириллицей в коде.
Если он сработал — строку нужно вынести в ARB, а не отключать проверку.

Есть исключения, и они помечены в коде комментарием: `label` у моделей и
функции в `lib/core/format.dart` остались русскими намеренно — они попадают в
журналы, а не в интерфейс. Подписи для показа берутся из `lib/ui/labels.dart`.

**Метка правила сохранений не переводится.** По ней правила сопоставляются
между устройствами: переведись она, снимок с русской машины перестал бы
сходиться с правилом на английской. Хранится она неизменной, переводится
только показ.

## Как писать код

Комментарии объясняют **почему**, а не что: что делает строка, видно из неё
самой. Хороший комментарий отвечает на вопрос «почему не проще?» —
особенно там, где решение выглядит странно.

Тест называется утверждением о поведении, а не именем метода: «свежий
прогресс не затирается старым пакетом» полезнее, чем «testBulkImport».

Правка, меняющая поведение, идёт с тестом. Правка, исправляющая ошибку, — с
тестом, который без неё падает.

## Что стоит обсудить до правки

Если задумали крупное — новый экран, замену зависимости, смену формата
`.evsave` — заведите issue до того, как писать код. Формат снимков особенно:
его читают чужие сборки на других устройствах, и несовместимое изменение
рвёт перенос сохранений, ради которого всё и затевалось.

---

# Contributing

A bug report, a translation fix, a note about clumsy wording — all of it is
welcome. Here is what to know before sending a change.

## Getting started

```bash
flutter pub get
flutter test
```

The tests need neither the network, nor a gamepad, nor a built app. Some are
skipped where there is nothing to check against: the registry work, and the
registry keys from the path database, outside Windows. That is expected, not a
failure.

Building for Linux needs `libayatana-appindicator3-dev` — the tray icon will
not compile without it. Building for macOS needs full Xcode, not just the
Command Line Tools.

## What CI checks

```bash
dart format --set-exit-if-changed lib test tool
flutter analyze
flutter test
```

**The analyzer treats infos as failures, not just errors.** Read its whole
output rather than filtering for the word `error`, or the change will reach CI
and come back red.

The three platform builds run on a `v*` tag only. To check that the project
builds without cutting a release, run the workflow by hand.

## Interface strings

Every visible string lives in `lib/l10n/app_ru.arb` and `app_en.arb`. Russian
is the source, English is required: a test compares the key sets and makes
sure the placeholders have not drifted apart.

Another test walks `lib/ui` and fails on any Cyrillic string left in the code.
When it fires, move the string into the ARB rather than disabling the check.

There are exceptions, marked in the code with a comment: the `label` getters
on models and the functions in `lib/core/format.dart` stay Russian on purpose
— they go into logs, not into the interface. Display labels come from
`lib/ui/labels.dart`.

**The save rule label is not translated.** Rules are matched between machines
by it: were it translated, a snapshot from a Russian machine would stop
matching a rule on an English one. It is stored unchanged; only its display is
translated.

## How to write the code

Comments explain **why**, not what: what a line does is visible in the line.
A good comment answers "why not simpler?" — especially where the decision
looks odd.

A test is named after the behaviour it asserts, not after a method: "fresh
progress is not overwritten by an older package" beats "testBulkImport".

A change in behaviour comes with a test. A bug fix comes with a test that
fails without it.

## Worth discussing first

For anything large — a new screen, swapping a dependency, changing the
`.evsave` format — open an issue before writing code. The snapshot format
especially: other builds read it on other machines, and an incompatible change
breaks the save portability the whole thing exists for.
