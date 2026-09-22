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

Для сборки под Linux нужны `libgtk-3-dev`, `libx11-dev` и `libxi-dev` —
без двух последних не соберётся значок в трее. Для сборки под macOS — полный Xcode, не только
Command Line Tools.

## Что проверяется в CI

Всё, что CI проверяет на каждой правке, собрано в одну команду:

```bash
dart tool/gate.dart
```

Это формат, анализатор, правила bloc, сверка регистраторов плагинов, тесты в
случайном порядке и порог покрытия. Хотите, чтобы она шла перед каждым
`git push`, — `git config core.hooksPath .githooks`.

Покрытие ворота меряют по отчёту своей системы, а CI — по слитому отчёту
трёх: тесты там пропускают разное. Поэтому список почти не проверенных
файлов локально только показывается, а решает задание «Покрытие».

**Анализатор считает провалом и подсказки, не только ошибки.** Смотрите весь
его вывод, а не отфильтрованный по слову `error`, — иначе правка доедет до CI
и вернётся оттуда красной.

Сборки трёх платформ идут на теге `v*` и раз в неделю по расписанию, а не
на каждом пуше. Проверить, что проект собирается, не выпуская версию, можно
ручным запуском прогона.

## Как выпустить версию

Версию задаёт тег — ни в коде, ни в `pubspec.yaml` её держать не нужно.

1. Опишите версию в `CHANGELOG.md`: раздел `## [0.24.0] — дата` вверху файла
   и ссылка на тег вниз, в общий блок. Из этого раздела и берётся описание
   релиза, отдельно оно не пишется.
2. **Сверьте каждую строку раздела с `git diff v<прошлая>..HEAD`**, а не с
   планом. Запись 0.36.0 обещала единый график скорости, которого в коде не
   было, — её пришлось исправлять разделом следующей версии. Внутреннее —
   прогоны, стражи, устройство кода — в историю для людей не пишут, а то,
   что касается их адреса и данных (утечки мимо прокси, подлинность
   обновления), идёт первым, разделом «Безопасность».
3. **Десять минут руками — то, чего не видит ни один прогон.** Сборки CI
   запускают приложение (`--smoke`) и репетируют обновление на macOS, но
   сеть, чужие сейвы и настоящая установка остаются за ними. Если версия
   трогает обновление, раскладку сохранений или движок загрузок — пройти
   всё; иначе хотя бы первый пункт:
   - обновление по нажатию с прошлого релиза на Windows — копия, поставленная
     установщиком;
   - малая легальная раздача по magnet через SOCKS5 — до «Играть»;
   - выход из игры → автоснимок → восстановление поверх изменённых сейвов;
   - `.evsave` с одной системы восстановлен на другой;
   - недоступный прокси: запросы отказывают, а не уходят напрямую, и об
     этом приходит сообщение;
   - `.run` на Linux: поставить, обновить по нажатию, удалить.
4. Коммит.
5. Тег и отправка:

```bash
git tag -a v0.24.0 -m "Evaporate 0.24.0"
git push origin main
git push origin v0.24.0
```

Дальше всё делает CI: сверяет, что раздел для тега на месте — до сборок, а не
после, — гоняет тесты на трёх системах, собирает установщики, считает
`SHA256SUMS`, заводит релиз черновиком, выкладывает файлы и только потом
публикует, иначе подписчики получают письмо о версии, скачать которую ещё
нечего.

Номер попадает в сборку оттуда же, из тега: `--build-name` в свойства файла и
`--dart-define` в само приложение, откуда его читает проверка обновлений.
Собранное на своей машине числится версией `0.0.0` — это и значит «не релиз».

Два места, где уже спотыкались:

- **Тег ставят на зелёный `main`.** Прогон тега гоняет те же тесты, и 0.19.0
  с 0.20.0 из-за упавших прогонов так и не вышли — пришлось выпускать 0.21.0.
- **С `push.followTags = true` в конфиге обычный `git push` утаскивает и
  локальные теги.** Однажды это воскресило уже удалённый тег: удалять надо
  сначала локально, потом на сервере.

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

Несколько правил держит не рецензия, а прогон — стражи в `test/guards/`:

- один файл — один публичный виджет; ни приватных виджетов, ни методов,
  возвращающих виджеты (кроме `build`);
- облик задаёт тема: в виджетах нет `isDark`, кегля, длительностей и
  радиусов числами;
- блоки, сервисы, модели и ядро не импортируют `lib/ui`;
- функция не сложнее 15, не длиннее 60 строк и не глубже 3 уровней
  (`dart tool/check_complexity.dart` покажет самые тяжёлые);
- новое состояние — блок с событиями; Cubit — только для мимолётного
  состояния одного виджета без асинхронной работы.

У стражей есть списки старых нарушителей. Пополнять их нельзя; исправив
нарушение, запись из списка вычеркните — страж сам об этом напомнит.

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

Building for Linux needs `libgtk-3-dev`, `libx11-dev` and `libxi-dev` — the
tray icon will not compile without the last two. Building for macOS needs full Xcode, not just the
Command Line Tools.

## What CI checks

Everything CI checks on every change is one command:

```bash
dart tool/gate.dart
```

That is formatting, the analyzer, the bloc rules, the plugin registrant check,
the tests in random order and the coverage threshold. To run it before every
`git push`, set `git config core.hooksPath .githooks`.

The gate measures coverage from your own system's report, CI from the merged
report of all three: the tests skip different things on each. So locally the
list of barely tested files is only shown; the Coverage job decides.

**The analyzer treats infos as failures, not just errors.** Read its whole
output rather than filtering for the word `error`, or the change will reach CI
and come back red.

The three platform builds run on a `v*` tag and once a week on a schedule,
not on every push. To check that the project builds without cutting a release,
run the workflow by hand.

## Cutting a release

The tag sets the version — there is nothing to bump in the code or in
`pubspec.yaml`.

1. Describe the version in `CHANGELOG.md`: a `## [0.24.0] — date` section at
   the top of the file, and the tag link at the bottom, in the block with the
   rest. That section becomes the release notes; they are not written twice.
2. **Check every line of the section against `git diff v<previous>..HEAD`**,
   not against the plan. The 0.36.0 entry promised a single speed chart the
   code never had, and the next version had to correct it. Internal work —
   CI, guards, code structure — stays out of a history written for people;
   what touches their address and data (leaks past the proxy, update
   authenticity) goes first, under «Безопасность» (Security).
3. **Ten minutes by hand — what no CI run sees.** The CI builds start the
   app (`--smoke`) and rehearse the update on macOS, but the network, real
   saves and a real installation stay out of their reach. If the version
   touches updates, save layout or the download engine, go through all of
   it; otherwise at least the first item:
   - a one-click update from the previous release on Windows, on a copy set
     up by the installer;
   - a small legal torrent by magnet through SOCKS5, all the way to "Play";
   - quit a game → automatic snapshot → restore over changed saves;
   - an `.evsave` from one system restored on another;
   - an unreachable proxy: requests fail instead of going direct, and a
     message says so;
   - the Linux `.run`: install, update in one click, remove.
4. Commit.
5. Tag and push:

```bash
git tag -a v0.24.0 -m "Evaporate 0.24.0"
git push origin main
git push origin v0.24.0
```

CI does the rest: it checks the tag's section is there — before the builds,
not after — runs the tests on three systems, builds the installers, computes
`SHA256SUMS`, opens the release as a draft, uploads the files and only then
publishes it, so that subscribers never get an email about a version with
nothing to download yet.

The number reaches the build from the same tag: `--build-name` for the file's
properties and `--dart-define` for the app itself, where the update check
reads it. A build made on your own machine reports version `0.0.0` — which is
exactly what "not a release" means.

Two places that have caught us out:

- **Tag a green `main`.** The tag run repeats the same tests, and 0.19.0 and
  0.20.0 never shipped because theirs went red — 0.21.0 went out instead.
- **With `push.followTags = true` in your config, a plain `git push` carries
  local tags along.** That once resurrected an already-deleted tag: delete
  locally first, then on the server.

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

A few rules are held by the test run rather than by review — the guards in
`test/guards/`:

- one file, one public widget; no private widgets and no methods returning
  widgets (other than `build`);
- the theme sets the look: no `isDark`, font sizes, durations or radii as
  numbers inside widgets;
- blocs, services, models and core never import `lib/ui`;
- a function stays within complexity 15, 60 lines and 3 levels of nesting
  (`dart tool/check_complexity.dart` lists the heaviest);
- new state is a bloc with events; a Cubit only for fleeting state of a
  single widget with no asynchronous work.

Each guard carries a list of older violations. The list must not grow; once
you fix a violation, strike its entry — the guard will remind you.

## Worth discussing first

For anything large — a new screen, swapping a dependency, changing the
`.evsave` format — open an issue before writing code. The snapshot format
especially: other builds read it on other machines, and an incompatible change
breaks the save portability the whole thing exists for.
