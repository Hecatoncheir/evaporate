# Чужие компоненты

Evaporate распространяется под лицензией MIT (см. [LICENSE](LICENSE)). Вместе
с ним поставляется чужая работа, у которой свои условия — они перечислены
ниже. Ни одно из этих условий не ограничивает использование самого Evaporate,
но соблюдать их обязан всякий, кто распространяет сборки.

*[In English](#third-party-components)*

## Что входит в сборку

### Манифест путей сохранений

База известных расположений сохранений — единственный источник, по которому
приложение находит папки сейвов. Сама собрана из [PCGamingWiki][pcgw]. В
репозиторий и в сборку не входит: скачивается приложением по требованию и
хранится в кэше.

- Лицензия: MIT
- Автор: mtkennerly
- Исходники: https://github.com/mtkennerly/ludusavi-manifest

[pcgw]: https://www.pcgamingwiki.com/wiki/Home

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

### Save-path manifest

The database of known save locations — the only source the app uses to find
save folders. Compiled from [PCGamingWiki][pcgw] itself. Part of neither the
repository nor the builds: the app downloads it on demand and keeps it in its
cache.

- License: MIT
- Author: mtkennerly
- Source: https://github.com/mtkennerly/ludusavi-manifest

[pcgw]: https://www.pcgamingwiki.com/wiki/Home

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
