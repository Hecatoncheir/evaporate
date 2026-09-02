# Чужие компоненты

Evaporate распространяется под лицензией MIT (см. [LICENSE](LICENSE)). Вместе
с ним поставляется чужая работа, у которой свои условия — они перечислены
ниже. Ни одно из этих условий не ограничивает использование самого Evaporate,
но соблюдать их обязан всякий, кто распространяет сборки.

*[In English](#third-party-components)*

## Что входит в сборку

### Ludusavi

Открытый инструмент резервного копирования игровых сохранений, у которого
приложение спрашивает пути. Кладётся рядом с исполняемым файлом при сборке.

- Лицензия: MIT
- Автор: mtkennerly
- Исходники: https://github.com/mtkennerly/ludusavi
- Тексты лицензий самого Ludusavi и всех его зависимостей кладутся в сборку
  рядом с бинарником (папка `ludusavi-legal`).

Бинарник в репозитории не хранится: он скачивается по закреплённой версии и
сверяется по контрольной сумме (`tool/fetch_ludusavi.py`).

### Манифест путей сохранений

База известных расположений сохранений — запасной источник, когда Ludusavi
недоступен. В репозиторий не входит: скачивается приложением по требованию и
хранится в кэше.

- Лицензия: MIT
- Исходники: https://github.com/mtkennerly/ludusavi-manifest

### Шрифты

Лежат в `assets/fonts/`, тексты лицензий — рядом с ними.

| Шрифт | Лицензия | Файл лицензии |
|---|---|---|
| Nunito | SIL Open Font License 1.1 | `assets/fonts/OFL-Nunito.txt` |
| Nunito Sans | SIL Open Font License 1.1 | `assets/fonts/OFL-NunitoSans.txt` |
| JetBrains Mono | SIL Open Font License 1.1 | `assets/fonts/OFL-JetBrainsMono.txt` |

OFL допускает распространение шрифтов в составе программы и требует
прикладывать текст лицензии — он приложен.

## Библиотеки

Зависимости из `pubspec.yaml` под своими лицензиями; полный список
показывает `flutter pub deps`. Отдельно стоит назвать движок загрузок:

- `dtorrent_task_v2` — клиент BitTorrent на Dart, на нём держатся загрузки.

---

# Third-party components

Evaporate is distributed under the MIT license (see [LICENSE](LICENSE)). It
ships with work by others, under their own terms, listed below. None of these
terms restrict the use of Evaporate itself, but anyone redistributing builds
must honour them.

## Bundled with the builds

### Ludusavi

The open save-file backup tool the app asks for save locations. Placed next to
the executable at build time.

- License: MIT
- Author: mtkennerly
- Source: https://github.com/mtkennerly/ludusavi
- The license texts of Ludusavi and all of its dependencies are placed in the
  build next to the binary (the `ludusavi-legal` folder).

The binary is not stored in this repository: it is downloaded at a pinned
version and verified against a checksum (`tool/fetch_ludusavi.py`).

### Save-path manifest

The database of known save locations — the fallback when Ludusavi is
unavailable. Not part of the repository: the app downloads it on demand and
keeps it in its cache.

- License: MIT
- Source: https://github.com/mtkennerly/ludusavi-manifest

### Fonts

They live in `assets/fonts/`, with their license texts beside them.

| Font | License | License file |
|---|---|---|
| Nunito | SIL Open Font License 1.1 | `assets/fonts/OFL-Nunito.txt` |
| Nunito Sans | SIL Open Font License 1.1 | `assets/fonts/OFL-NunitoSans.txt` |
| JetBrains Mono | SIL Open Font License 1.1 | `assets/fonts/OFL-JetBrainsMono.txt` |

The OFL permits bundling fonts with a program and requires the license text to
be included — it is.

## Libraries

The dependencies in `pubspec.yaml` come under their own licenses; `flutter pub
deps` lists them all. One deserves a separate mention:

- `dtorrent_task_v2` — the Dart BitTorrent client the downloads rest on.
