# TODO — оценка кода и план улучшений

Разбор сделан 2026-09-19 по состоянию `main` на коммите `1b33588`.
Прочитан весь `lib/` (32 тыс. строк), `test/`, `tool/` и CI: тема, блоки и
`main.dart` — напрямую, сервисы, экраны и тесты — четырьмя параллельными
рецензиями, ключевые находки которых затем перепроверены по коду. Ничего,
кроме этого файла, не менялось; тесты и сборка не запускались.

Как читать:

- **P0** — ошибка или риск потери данных, чинится первым и с тестом,
  который без правки падает (правило из `CLAUDE.md`);
- **P1** — правила, которые владелец проекта считает обязательными:
  минимальная когнитивная сложность, ни одного приватного виджета, тема;
- **P2** — архитектура состояния; **P3** — гигиена;
- трудоёмкость: **S** — до пары часов, **M** — до дня, **L** — несколько дней;
- 💬 — по `CLAUDE.md` сначала issue (новая зависимость, новый экран,
  смена устройства слоёв).

Числа ниже сняты эвристическим скриптом (комментарии и строки вырезаны,
функции найдены по скобкам, счёт по мотивам когнитивной сложности
SonarSource: +1 за ветвление и цикл, +уровень вложенности, +1 за смену
логического оператора, +1 за тернарник). Это ранжирование «где болит», а
не точный замер; как превратить его в ворота — см. этап 0.

---

## 1. Оценка

| Область | Оценка | Коротко |
|---|---|---|
| Документация и «почему» в комментариях | 5 / 5 | `CLAUDE.md` и комментарии объясняют решения и их цену — редкость. Есть осиротевшие комментарии после распила блоков (этап 1). |
| Тесты и ворота CI | 4.5 / 5 | 940 тестов на 32 тыс. строк, три системы, порог покрытия, тесты-стражи (локализация, контраст, имена артефактов), только ручные фейки. Нет стражей на структуру виджетов, слои и сложность; сборка проверяется только на теге; `DownloadsBloc` покрыт наполовину, потому что движок в него не подменить. |
| Сервисы | 4 / 5 | Транзакция восстановления (план до первой записи, откат, zip-slip, отказ от симлинков), подмена платформы функциями в конструкторе, `AppShutdown`. Но есть серьёзные находки: распаковка обновления не знает симлинков бандла macOS, ошибка загрузки вечна и держит слот, прокси при сбое открывается напрямую (этап 1). Два класса-комбайна: `SaveManager` и `DtorrentEngine`. |
| Когнитивная сложность | 4 / 5 | Из 1357 функций только 4 выше 15 и 26 выше 10. Но 140 функций длиннее 40 строк, 38 — длиннее 60: почти всё это `build` и обработчики блоков. |
| Состояние (Bloc) | 3.5 / 5 | Событийная модель честная, внешние источники поданы событиями. Слабые места: события носят **снимок** игры (гонка «потерянного обновления»), блоки держат друг друга напрямую, бизнес-логика осталась в `State` пяти виджетов. |
| Тема | 3.5 / 5 | Цвета — образцово: `ThemeExtension`, две роли у фирменного цвета, контраст под тестом, сырых цветов в виджетах нет. Нет **типографики**: 184 `TextStyle(...)` по месту в 49 файлах, `textTheme` виджеты не читают ни разу. Около 30 ветвлений `isDark` в 12 файлах виджетов. |
| Структура виджетов | 2.5 / 5 | Против правила «приватных виджетов нет»: 41 приватный виджет, 70 методов, возвращающих виджеты, 35 файлов, где виджетов больше одного (из них 18 — с несколькими публичными). Зато вынос обнажит с десяток повторов, которые сейчас не видны. |

Что сделано хорошо и что трогать не надо:

- токены цвета и моторики через `ThemeExtension`, доступ `context.colors` /
  `context.motion`, системная просьба «не двигаться» соблюдается в одном месте;
- единый `primaryActionFor` вместо четырёх `switch`;
- `JsonStore` (атомарность, очередь, права до переименования), `AppShutdown`,
  хранилище снимков по содержимому с `guard`;
- очередь `asyncExpand` у поиска метаданных, маркер «уже пробовали» до сети;
- тесты-стражи как способ держать правило — этот же приём предлагается
  ниже для новых правил.

---

## 2. Ответы на вопросы о теме

### Хорошо ли сделана тема

Фундамент — да. Не хватает двух верхних этажей:

1. **Типографики нет вовсе.** `EvaporateTheme._textTheme` настраивает
   `TextTheme`, но виджеты его не читают (`textTheme.` в `lib/ui` — ноль
   вхождений). Вместо этого 184 раза написан `TextStyle(...)` по месту, 82
   разных сочетания. Шесть самых частых дают половину всех случаев:

   | Раз | Размер | Вес | Цвет |
   |---|---|---|---|
   | 32 | 13 | — | — |
   | 16 | 12.5 | — | `textSecondary` |
   | 14 | 12 | — | `textSecondary` |
   | 9 | 13 | — | `textSecondary` |
   | 9 | 12 | — | — |
   | 8 | 13 | w600 | — |

   А «моно-метка капсом» уже разошлась сама собой: 9 / w700 / +1.4 в
   `ReadoutCell` (`readout_panel.dart:94`), 8.5 / w700 / +1.4 в
   `_PlaytimeReadout` (`featured_game.dart:418`), 9.5 / w800 / +1.6 в
   `_Eyebrow` (`featured_game.dart:336`). Это ровно тот довод, которым в
   `motion.dart` обоснованы токены длительностей: «разбросанные по виджетам
   числа расходятся сами собой».

2. **Различие схем записано кодом, а не данными.** `CLAUDE.md` называет
   схемы «двумя самостоятельными обликами», но облик компонента решается
   внутри виджета: `colors.isDark ? 0.9 : 0.94`. Таких ветвлений около
   тридцати в двенадцати файлах; в одном `GlassSurface` их шесть
   (`spatial_surface.dart:79–118`). Третья схема
   (высокий контраст, OLED) потребовала бы правки каждого виджета.
   Туда же — пары констант, названные по схеме и выбираемые через `isDark`:
   `hardwareShadowDark/Light`, `grilleHoleDark/Light`, `frostDark/Light`
   (`app_colors.dart:271–289`). Это токены темы, лежащие мимо темы.

Мелочи: `AppColors.heroEyebrow`, `ambientWarm` и `dark.primary` — одно и то
же `0xFFE9C877`, записанное трижды; у Material-компонентов тема задана не
всем (нет `textButtonTheme`, `iconButtonTheme`, `switchTheme`,
`checkboxTheme`), поэтому стиль доопределяют по месту через `styleFrom`
(`featured_game.dart:380`, `common.dart:190`, `common.dart:432`); `copyWith`
и `lerp` на 20 полей написаны руками — забытое в `lerp` поле молча ломает
плавную смену схемы.

### Как во Flutter лучше всего делать темы для виджетов

Три яруса токенов, и каждый следующий берёт значения только у предыдущего:

| Ярус | Что это | Где живёт | Как доступно |
|---|---|---|---|
| 1. Примитивы | сырые значения: `0xFFE9C877`, 13 pt, 380 мс | приватные константы в файлах схем | никак: виджеты их не видят |
| 2. Семантика | роли: `textSecondary`, `primaryFill`, `caption`, `motion.base` | `ThemeExtension`: палитра ✔, моторика ✔, **типографика — добавить** | `context.colors`, `context.motion`, `context.text` |
| 3. Компонент | ручки одного виджета: прозрачность панели, торец клавиши, ореол | `ThemeExtension` **на компонент** — для своих виджетов; `ThemeData.*Theme` — для Material | `GlassSurfaceTheme.of(context)` |

Так устроен сам Flutter: у `Card` есть `CardThemeData`, виджет читает
`CardTheme.of(context)` и достраивает умолчания из `ColorScheme`. Для своих
виджетов штатная точка расширения — `ThemeExtension<T>`.

### Класс темы у каждого виджета?

**Да, но не у каждого и не наследованием.**

- *Не у каждого.* Класс темы нужен компоненту, у которого выполняется хотя
  бы одно: сегодня в нём есть ветвление `isDark`; у него три и больше
  оформительских константы, которые захочется крутить; он переиспользуется
  с вариациями. Виджет, который только собирает другие и читает
  семантические токены, своей темы не заслуживает. Первые кандидаты:
  `GlassSurface` (6 ветвлений), `LauncherActionButton` (торец, ореол, ход
  клавиши), `SpatialBackdrop`, `HardwareGrille`, `AmbientLight`,
  `ReadoutPanel`, кадр `FeaturedGame` (тень), рейка навигации, `CoverBackdrop`.
- *Не наследованием.* Схема «абстрактный `ButtonTheme` + `DarkButtonTheme` и
  `LightButtonTheme`, которые его реализуют» во Flutter не работает: тема —
  это **данные, а не поведение**. Нужен один иммутабельный класс и два его
  **экземпляра**. Наследники ломают `lerp` (плавная смена схемы идёт через
  `AnimatedTheme` и смешивает расширения по полям), `copyWith` и локальное
  переопределение через `Theme(data: …)`.

```dart
/// Материал панели. Схемы расходятся здесь данными, а не ветвлениями.
class GlassSurfaceTheme extends ThemeExtension<GlassSurfaceTheme> {
  const GlassSurfaceTheme({
    required this.fillOpacity,
    required this.sheenOpacity,
    required this.rimOpacity,
    required this.shadow,
    required this.counterLightOpacity,
  });

  final double fillOpacity;
  final double sheenOpacity;
  final double rimOpacity;
  final Color shadow;
  final double counterLightOpacity;

  static const arclight = GlassSurfaceTheme(
    fillOpacity: 0.9, sheenOpacity: 0.62, rimOpacity: 0.15,
    shadow: Color(0x8C000000), counterLightOpacity: 0.05,
  );
  static const cartridge = GlassSurfaceTheme(
    fillOpacity: 0.94, sheenOpacity: 0.72, rimOpacity: 0.32,
    shadow: Color(0x578A8574), counterLightOpacity: 0.16,
  );

  static GlassSurfaceTheme of(BuildContext context) =>
      Theme.of(context).extension<GlassSurfaceTheme>() ?? arclight;

  // copyWith и lerp — как у EvaporatePalette.
}
```

Порядок старшинства тот же, что у Material: **параметр виджета → тема
компонента → умолчание из семантических токенов** (`opacity ?? t.fillOpacity`).

### Хранить тему отдельно от виджетов или рядом

По ярусам:

- **семантические токены** (палитра, типографика, моторика, геометрия) —
  централизованно, в `lib/ui/theme/`: ими пользуются все, и схема обязана
  читаться с одного взгляда;
- **класс темы компонента** — **рядом с виджетом**
  (`widgets/glass_surface/glass_surface.dart` +
  `glass_surface_theme.dart`): это часть его API, он меняется и удаляется
  вместе с ним. Так лежит и у Flutter: `card.dart` и `card_theme.dart` рядом;
- **значения обеих схем** — в том же файле темы компонента, двумя
  константами подряд (`arclight`, `cartridge`): оба облика компонента видны
  разом, и правка одного не забывает второй;
- **сборка** — в одном месте, `EvaporateTheme._build`: только оно знает
  полный список расширений. Страж (этап 0) проверяет, что набор расширений у
  двух схем совпадает и каждое переживает `lerp`.

Что остаётся константой мимо темы — и это нормально: радиусы и семейства
шрифтов в `EvaporateTheme` одни на обе схемы и нужны в `const`-контексте.

---

## 3. Bloc или Cubit

Сейчас правило в `CLAUDE.md` разрешает Cubit «где событие ничего не
добавляет». Предлагается ужесточить — **по умолчанию Bloc**:

> Cubit допустим, только если верно всё сразу: состояние живёт не дольше
> одного виджета или диалога; нет асинхронной работы и внешних источников;
> переходы — простые присваивания (переключатель, выбранная вкладка).

Почему Bloc, а не «тот же блок без обряда»:

1. **Журнал причин.** У события есть имя, и `BlocObserver` пишет в `AppLog`
   «что случилось → что изменилось». Для приложения, где журнал —
   единственный способ узнать, что произошло у человека, это главный довод.
   `BlocObserver` сейчас не заведён вовсе (этап 4).
2. **Трансформеры.** Задержка набора в поиске, «второе нажатие на
   „проверить обновления“ игнорируется», очередь — это свойства события.
   В проекте `asyncExpand` уже стоит в трёх местах.
3. **Один способ вместо двух** — меньше решений на каждую новую надобность,
   то есть меньше когнитивной нагрузки.

Оба нынешних Cubit новому правилу не проходят:

| Сейчас | Почему не Cubit | Что сделать |
|---|---|---|
| `SaveFreshnessCubit` | асинхронное чтение диска | `RestorePreviewBloc` с событием `RestorePreviewRequested(game, snapshot)`: заодно забирает из диалога восстановления всё, что тот считает сам (этап 4). Три состояния «не знаем / не было / менялись тогда-то» сохраняются. **S** |
| `DownloadHistoryCubit` | источник внешний — движок; по правилу из `CLAUDE.md` это уже признак блока. Кормит его виджет `DownloadHistoryScope` через `didUpdateWidget` (`download_activity.dart:35`), и отсюда три беды. У одной задачи **две истории**: карточка в очереди (`task_card.dart:60`) и страница игры (`game_detail.dart:82`) живут одновременно, каждая со своим Cubit, — ровно то расхождение, ради защиты от которого Cubit заводили. История умирает вместе с виджетом: прокрутил список или закрыл страницу — график с нуля. При замершей загрузке выборок нет (`download_history_cubit.dart:53–57`), и «минута до сейчас» перестаёт двигаться | `DownloadHistoryBloc` уровня приложения: события `TasksSampled(tasks)` из потока движка (как `_pushTasks`, `downloads_bloc.dart:112`) и `TaskForgotten(id)`; состояние — истории по id задачи, `peak` и `diskSpeed` — поля, а не методы; часы подменяемые (`DateTime.now()` зашит в `:37,59`). **M** |

Где логика сидит в `State` и просится в блок — этап 4. Что законно остаётся
в `State`: наведение, нажатие, `FocusNode`, контроллеры текста и прокрутки,
тикеры анимаций.

`NavigationBloc` остаётся блоком — решение принято раньше и с новым
правилом согласуется.

---

## 4. План

### Этап 0. Стражи — сначала ворота, потом уборка (P1)

Правило без ворот не держится, а нарушений уже 41 + 70 + 18. Приём —
**храповик**: тест-страж несёт список известных нарушителей; список
нельзя пополнять, а запись, которая перестала нарушать, обязана быть
вычеркнута (тест падает на устаревшей записи). Уборка идёт по частям, а
новых нарушений не появляется с первого дня.

- [x] `test/widget_structure_test.dart` — обходит `lib/ui`, как
  `localization_test.dart`, и падает на: `class _X extends
  (Stateless|Stateful|Inherited…)Widget`; метод, возвращающий `Widget` /
  `List<Widget>`, кроме `build`; больше одного класса-виджета в файле.
  `_XState` законны: это идиома Flutter, а не приватный виджет. **S**
- [x] `tool/check_complexity.dart` + `test/complexity_test.dart` — длина
  функции, вложенность, счёт ветвлений; пороги: сложность ≤ 15, длина ≤ 60,
  вложенность ≤ 3, затем опускать следом за достигнутым (как порог
  покрытия). Первая версия — без зависимостей, на регулярках; точная — на
  `package:analyzer` 💬. **M**
- [x] `test/theme_structure_test.dart` — в `lib/ui` вне `lib/ui/theme/` нет
  `isDark`, нет `TextStyle(` с `fontSize:`, нет `Duration(milliseconds:` и
  `BorderRadius.circular(<число>)`; набор расширений у двух схем совпадает.
  Тоже храповиком. **S**
- [x] `test/layering_test.dart` — `lib/bloc`, `lib/services`, `lib/models`,
  `lib/core` не импортируют `lib/ui`; `lib/models` и `lib/core` не
  импортируют Flutter и сервисы. Сегодня он нашёл бы:
  `downloads_bloc.dart:21` (`ui/labels.dart`), `navigation_bloc.dart:2,57`
  (`FocusNode` в блоке), `models/app_settings.dart:2,4` (`material` и
  `input`), `models/save_snapshot.dart:1` (сервис). **S**
- [x] Линтер. Даром, срабатываний ноль: `avoid_catches_without_on_clauses`
  (все 58 `catch` уже с `on`), `avoid_void_async`. С правкой:
  `only_throw_errors` (бросают строки — `add_game_dialog.dart:306,321,337,338`),
  `prefer_single_quotes` (23 места; заодно закрывает дыру стража кириллицы —
  тот видит только литералы в одинарных кавычках,
  `localization_test.dart:165`), `no_adjacent_strings_in_list`,
  `prefer_const_literals_to_create_immutables` (выпало из набора вместе с
  теми двумя, что проект уже вернул), `unnecessary_await_in_return`,
  `avoid_positional_boolean_parameters` (около 12 мест). `discarded_futures`
  — вложенным `analysis_options.yaml` только для `lib/bloc` и
  `lib/services`: в UI он зашумит. Строка `use_super_parameters`
  (`analysis_options.yaml:52`) лишняя — правило уже в наборе. **S**
- [ ] `bloc_lint` 💬. Его `prefer_bloc` — ровно правило «по умолчанию Bloc»,
  поставленное на ворота; из рекомендованного набора полезны
  `avoid_flutter_imports` и `avoid_public_fields`. Запускается не
  анализатором, а `bloc lint .` из `bloc_tools` — отдельный шаг CI.
  `avoid_public_bloc_methods` сработает на осознанных `persist()`,
  `snapshotBeforeLaunch`, `applyLimits`, `closeOpenedGame` — их придётся
  либо исключить с объяснением, либо перевести в события. **S**
- [x] Страж мёртвых ключей ARB: сейчас их девять (`downloadPaused`,
  `findGamesInFolder`, `gamesWithPaths`, `noticeRestorePartial`, `ofAmount`,
  `pickGameOnTheLeft`, `torrentFallbackName`, `updateNoteLine1`,
  `updateNoteLine2`). **S**
- [x] Записать новые правила в `CLAUDE.md` и `CONTRIBUTING.md` — иначе их
  знает только этот файл: «по умолчанию Bloc» (вместо нынешнего раздела про
  Cubit), «один файл — один публичный виджет, методов-виджетов нет», три
  яруса темы и где что лежит, пороги сложности. **S**

### Этап 1. Ошибки и риски (P0)

Всё здесь найдено **чтением кода**, без запуска. По правилу проекта каждая
правка начинается с теста, который без неё падает, — он же и подтвердит
или снимет находку. Сначала — то, что грозит данным и главной функции.

**Сервисы**

- [x] **Обновление по нажатию на macOS, похоже, ломает бандл.** CI пакует
  архив через `ditto` именно ради симлинков (`ci.yml:178–179`), а
  распаковщик о них не знает: `_extract` (`update_download.dart:273–291`)
  различает только «файл» и «папку», и ссылка ляжет обычным файлом с путём
  внутри. У бандла это `Versions/Current` и сам бинарник фреймворка —
  приложение не стартует, а помощник к этому времени уже убрал прежнюю
  копию. Пакеты сохранений симлинки отвергают явно
  (`restore_transaction.dart:22`), здесь такой проверки нет. На живой macOS
  не проверено. Лечение: создавать `Link` для записей-ссылок, с той же
  проверкой выхода за пределы папки; тест на архиве с симлинком. **M**
- [x] **`SteamGame.merge` забыл `screenshots`** (`steam_catalog.dart:45–51`).
  `bestMatch` (`:303`) сливает найденное по названию с подробностями — и
  кадры теряются: у всех игр, найденных по названию, а не по `appid`,
  подложка из кадров пуста. Тест подменяет `bestMatch` целиком
  (`automatic_metadata_test.dart:52`) и этого не ловит. **S**
- [x] **Ошибка загрузки вечна и держит слот.** `catch` в `_launch`
  (`engine_queue.dart:103–107`) ставит `error`, но оставляет `started`, и
  `_activeCount` (`:37`) продолжает считать задачу; `pumpQueue` (`:23`)
  задачу с ошибкой пропускает, а `resume` (`dtorrent_engine.dart:334`)
  ошибку не снимает. Повторить можно только перезапуском приложения; три
  ошибки при лимите в три запирают очередь. Не найденные метаданные дают
  `null` и тихий выход (`:79–84`) — задача навсегда в «получении
  метаданных». Корень — состояние задачи размазано по шести полям;
  лечится перечнем состояний слота с методами-переходами. **M**
- [x] **Уборка хранилища снимков закрыта от гонки не до конца.** Если работа
  под `guard` началась и закончилась, пока `collect` шёл по диску, закреплённое
  уже сброшено (`snapshot_store.dart:84`), а обход продолжается со старым
  списком живых (`:186–199`) и уносит свежее содержимое. Лечится счётчиком
  эпох: `guard` увеличивает, `collect` при смене прекращает обход. **S**
- [ ] **Прокси отказывает «в открытую».** Имя не разрешилось — создаётся
  прямой клиент (`proxy_http_overrides.dart:35,58`), и анонсы трекеру
  уходят с настоящего адреса; остаётся строка в журнале. Для настройки,
  которую включают ради скрытности, безопаснее отказ соединения и
  сообщение человеку 💬. **S**
- [x] **Пароль прокси мгновение читаем всем.** `CLAUDE.md` обещает «ни
  мгновения», но `_writeText` сначала пишет содержимое, потом зовёт `chmod
  600` (`json_store.dart:123–127`), и код возврата не проверяет. Порядок
  обратный: создать пустой файл, сменить права, записать. **S**
- [x] **Битый UTF-8 в `library.json` — приложение не дождётся библиотеки.**
  `JsonStore.read` ловит только `FormatException` (`json_store.dart:48`), а
  негодная кодировка приходит `FileSystemException`; карантина нет, у
  `_onLoadRequested` (`library_bloc.dart:245`) своего `catch` нет, и
  `loaded` не наступит. `readText` (`:79`) то же исключение ловит. Туда же
  ленивый `.cast<String>()` в `Game.fromJson` (`game.dart:258–262`): ошибка
  типа вылетит при первом чтении поля, мимо `try` в `:259`. **S**
- [x] **Двойной запуск игры.** Проверка «уже запущена»
  (`game_launcher.dart:74`) и регистрация процесса (`:128`) разделены
  ожиданиями, а `_onLaunchRequested` занятость не проверяет
  (`library_bloc.dart:399`): два быстрых нажатия дают два процесса, и выход
  первого стирает запись второго. Резервировать id синхронно. **S**
- [x] **`put` читает файл дважды** — раз для хеша, раз для содержимого
  (`snapshot_store.dart:112,115`). Игра дописала сейв между чтениями — под
  хешем ляжет другое содержимое, и позже это ничем не ловится. Считать хеш
  с тех же байтов, что пишутся. **S**
- [x] После падения между двумя переименованиями
  (`restore_transaction.dart:213–217`) сейвы остаются под
  `.evaporate-old-*`, а уборки таких остатков при следующем запуске нет —
  хотя `update_install.dart:91` её обещает. **M**
- [x] `ScanSession._run` без `try/finally` (`scan_session.dart:86`): любое
  исключение — например, незащищённый `list().any`
  (`library_scanner.dart:170`) — оставляет `_running` навсегда. **S**
- [x] `_openArchive` при исключении не закрывает `InputFileStream`
  (`save_manager.dart:705–715`): на Windows битый `.evsave` остаётся заперт
  до выхода. `_importPackage` (`:624–641`) не проверяет размер, в отличие
  от плана восстановления. **S**
- [x] `maxConcurrent` из файла не зажат (`app_settings.dart:273`): при нуле
  очередь не едет вовсе (`engine_queue.dart:22`). Остальные числа из
  профиля зажимаются — это пропущено. **S**
- [ ] Синхронная работа `archive` на главном изоляте: `writeContent`
  (`restore_transaction.dart:278`, `save_manager.dart:632`,
  `update_download.dart:282`), сжатие в `ZipFileEncoder.addFile`
  (`save_manager.dart:243`), чтение и разбор всего обновления в памяти
  (`update_download.dart:168,234`). При снимке в гигабайты это секунды
  замершего окна. `Isolate.run`, как уже сделано для базы путей. **M**
  *Сделано для обновления* — разбор и распаковка идут в изоляте. У сейвов
  по кускам не выйдет: восстановление снимка из хранилища сначала
  **собирает** временный zip (сжатие), а потом его же **разбирает**, и
  лечится это раскладкой прямо из хранилища, без пакета, — вместе с
  распилом `SaveManager` (этап 5).
- [x] Отчёт массовой загрузки врёт: старший дубликат пакета помечается
  «здешние сохранения новее» (`bulk_transfer.dart:165–172`). **S**
- [x] «Не понял — не трогай» у ярлыков Steam дыряво: `allowMalformed` с
  перекодированием молча меняют чужие не-UTF-8 строки
  (`binary_vdf.dart:94,148`), `addGame` выбрасывает значения не-`Map`
  (`steam_shortcuts.dart:248–254`); `pgrep -x steam` (`:178`) на macOS
  стоит проверить — процесс там зовётся иначе. **S**
- [x] Исключения гаснут без журнала: пропуск сверки контрольной суммы
  (`update_download.dart:195–198`), битые пакеты (`save_manager.dart:697`),
  `_adoptMetadata` (`managed_download.dart:96`), витрина
  (`steam_shortcuts.dart:389`). **S**
- [x] Наследие aria2 — не «ровно одно», как сказано в `CLAUDE.md`:
  `ProxySettings.bypass` никем не читается, `DownloadTask.followedBy` движок
  не заполняет (а `downloads_bloc.dart:375` читает),
  `DownloadState.removed` никто не порождает, `_Root.token/depth`
  (`save_path_finder.dart:203`) не используются. **S**

**Блоки и экраны**

- [x] **Потерянное обновление в `GameUpdated`.** Событие несёт целую игру —
  снимок на момент отправки. Обработчик (`library_bloc.dart:306–349`)
  спасает от затирания поля поимённо, и список спасаемых отстал от модели:
  в нём нет `rating` и `shotPaths`. Сценарий: добавили папку → пошёл
  автоматический поиск в Steam → человек тем временем выбирает исполняемый
  файл (`files_section.dart:66–69`: `game` захвачена до `await openFile()`)
  → Steam ответил, записал оценку и кадры → приходит `GameUpdated` со старой
  игрой → оценка и кадры стёрты, файлы кадров осиротели на диске, а
  `steamLookupAttempted` уже взведён, и сам поиск не повторится. Второй
  сценарий: игра запущена, на её странице открыт диалог правила
  (`saves_section.dart:194–227`, до трёх `await`); игра закрылась,
  `GameExited` дописал наигранное время; подтверждение диалога возвращает
  старые `playtime` и `status: running`. То же грозит любому новому полю.
  Лечение — событие несёт **намерение, а не снимок**, и обрабатывается от
  **текущей** игры, как это уже сделано в `_onSaveHintsAccepted`
  (`saves_hints.dart:43`): `GameStatusChanged(id, status, {lastError})`,
  `GameExecutableSet(id, path)`, `GameInstallDirSet(id, dir)` (поиск
  исполняемого — внутри блока, под ключом занятости),
  `GameDownloadLinked(id, taskId, infoHash)`, `GameInstalled(id, …)`, а для
  сохранений — `SaveRuleAdded(gameId, …)`, `SaveRuleRemoved(gameId, ruleId)`,
  `AutoSnapshotChanged(gameId, …)`. Слияние на 44 строки исчезает.
  Отправители: `downloads_bloc.dart` (12), `saves_bloc.dart:203`,
  `saves_section.dart:218,231`, `files_section.dart:69,122`,
  `action_panel.dart:222`, `auto_snapshot_toggle.dart:24`. **M**
- [x] **Пустой шаблон правила разворачивается в рабочую папку процесса.**
  «Сохранить» в `RuleDialog` активна всегда (`rule_dialog.dart:119–122`),
  `_draft()` шаблон только обрезает. `SavePathTemplate.expand('')` отдаёт
  `p.normalize('')`, то есть `.` (`save_path_template.dart:105`), а
  `SavePathRule.resolve` (`save_profile.dart:96`) пустоту не отсекает, и
  проверки на относительный путь в `SaveManager` нет. Снимок такого правила
  заберёт рабочую папку приложения, а восстановление с очисткой цели —
  очистит её. Лечение: `resolve` возвращает `null` для пустого и
  относительного результата; клавиша гаснет на пустом шаблоне; тест на оба. **S**
- [x] **Четвёртый путь добавления правил считает метки не так, как три
  остальных.** `saves_hints.dart:87` `_rulesFor` считает метки по всему
  набору правил, и комментарий там же требует, чтобы источники в этом не
  расходились. Но поиск по базе в `LibraryBloc`
  (`library_metadata.dart:572–583`, `_FoundPaths.labelFor`) считает их
  **только по найденному**: у игры с одним правилом «Сохранения» база
  находит один новый путь → `labelsFor` для единственного пути отдаёт ту же
  метку по умолчанию → в профиле два правила «Сохранения». На другом
  устройстве `_matchLocalRule` (`save_manager.dart:515–525`) от двоякой
  метки честно отказывается — и перенос для этой игры перестаёт работать:
  оба правила уходят в «не удалось сопоставить». Пятый путь — ручное
  добавление: `RuleDialog` предзаполняет ту же метку по умолчанию
  (`saves_section.dart:206`), и уникальность никто не проверяет. Лечение:
  одна функция на все пути (место ей — `SaveProfile.withAddedPaths`), а
  диалог не даёт сохранить метку, которая уже занята; тест на оба сценария. **S**
- [x] **Нажатие на уже выбранный набор эффектов бросает `StateError`.**
  `effects_card.dart:77–81`: стоит `emptySelectionAllowed: true`, а
  обработчик берёт `selection.first`. Нажатие на выбранный сегмент отдаёт
  пустое множество. Лечение: пустой выбор — не действие
  (`if (selection.isEmpty) return`), тест нажатием. **S**
- [x] **Поле скорости теряет набранное.** `speed_field.dart:77–78`: значение
  фиксируется только по Enter и щелчку мимо, а `settings_page.dart:63–72`
  нарочно уводит фокус из полей стрелками — поле продолжает показывать
  число, которое никуда не записано. Свой `onTapOutside` к тому же отменяет
  штатное снятие фокуса, а `didUpdateWidget` нет. Фиксировать на потере
  фокуса. **S**
- [x] **Во время захвата кнопки геймпада срабатывает её прежнее действие.**
  Сервис шлёт и сырую кнопку, и привязанное действие
  (`input/gamepad_service.dart:162–164`), `InputScope` их не глушит
  (`input/input_scope.dart:86–113`): нажатие Y в диалоге захвата
  (`gamepad_settings.dart:238–240`) уводит в библиотеку к поиску, LB/RB
  листают разделы. Захватывается и крестовина — вопреки правилу в `:20–21`,
  `assign` её не фильтрует (`input/gamepad_binding.dart:66`). Лечится блоком
  захвата, который на своё время глушит действия (этап 4). **S**
- [x] **`SettingsChanged` — та же болезнь, что у `GameUpdated`:** событие
  несёт весь `AppSettings`. `settings_page.dart:218–222,364–368`: настройки
  захвачены до `await getDirectoryPath()`, и правка, сделанная, пока открыт
  системный диалог, затирается. Окно узкое, но корень тот же. Правильно
  сделано в `sync_folder_card.dart:75–79`. Лечение — правка функцией от
  текущего значения: `SettingsPatched((s) => s.copyWith(…))`. **S**
- [ ] **Сброс файлов в окно — без `catch` и мимо `Notice`.**
  `widgets/game_drop_target.dart:88–180`: свой `_importing`, разбор путей,
  генерация id, ожидание `library.stream.firstWhere` (`:174`, копия из
  диалога добавления), `SnackBar` напрямую (`:119,125`). `finally` флаг
  гасит, но `catch` нет: исключение из `DropImport.inspect` уходит
  необработанным — человек бросил файл, и не произошло ничего, ни
  сообщения, ни записи в журнале. Лечение — событие `FilesDropped(paths)` в
  `LibraryBloc` (этап 4). **M**
- [x] **Запуск пишет устаревшую игру.** `library_bloc.dart:415`:
  `games[index] = game.copyWith(status: running)`, где `game` — из события, а
  перед этим два ожидания (снимок перед запуском идёт секунды). Брать
  `state.games[index]`. **S**
- [x] **Занятость, которую некому погасить.** `saves_bulk.dart:5–33`:
  `_onBulkExport` без `try` — исключение из `_resolveStoredPaths`, `_pruneAll`
  или `persist` оставит ключ `bulk` взведённым, и клавиши переноса погаснут
  до перезапуска. Лечится общим помощником (этап 4), у которого гашение — в
  `finally`. **S**
- [x] **Блок зависит от слоя UI.** `downloads_bloc.dart:21` импортирует
  `ui/labels.dart` ради `engineStateLabel`. Подписи, нужные блокам, —
  в нейтральное место (`lib/l10n/labels.dart`). **S**
- [x] **Осиротевшие комментарии** после распила `LibraryBloc`/`SavesBloc`:
  описание класса досталось `typedef GameExit` (`library_bloc.dart:31–39`);
  про массовый перенос — полю `_launcher` (`:142`); про манифест — геттеру
  `launcher` (`:170`); заголовок «сейвы» стоит над `close()` (`:468`);
  оборванные на полуслове — `library_metadata.dart:592`,
  `saves_snapshots.dart:170–174`; чужое описание у `_onSavePathsProgress`
  (`library_metadata.dart:458`); описание `_matchLocalRule` приклеилось к
  `previewTargets` (`save_manager.dart:488–489`); описание `StatusChip`
  уехало к `IconAction` (`common.dart:154`); «приходят из кубитов» про
  блоки (`shell.dart:89`). **S**
- [x] О новой версии уведомляют видом `NotificationKind.test`
  (`main.dart:339`) — завести `updateAvailable`. **S**

Риски помельче (P2), каждый — **S**:

- [x] Шейдер капель не освобождается при замене и сбросе
  (`cover_drops.dart:96,110`): `dispose()` зовётся только в `dispose`
  виджета, а замена случается на каждый уход выделения с плитки. Кодек не
  освобождается, если `getNextFrame` бросит (`:86–88`).
- [ ] Синхронный диск в `build`: `existsSync` дважды на каждое правило
  (`saves/rule_tile.dart:27–29`). Признак «папка есть» — подавать снаружи.
- [ ] Ошибки мимо `Notice` и журнала: `showError` и `SnackBar` прямо из
  виджетов — `saves_section.dart:250,416`, `detail/info_section.dart:111`
  (там же `Process.run` в виджете, `:102–113`), `detail/files_section.dart:80`.
- [x] Часов украшений три, а не одни, как обещает `CLAUDE.md`: шаг с
  ограничением `dt` скопирован в `library_atmosphere.dart:90–110`,
  `foil_card.dart:110–119` и `widgets/decorative_motion.dart:71–82`, причём
  атмосфера не смотрит на `lifecycleState` (`:47–50`), в отличие от двух других.
- [ ] Поиск папок сохранений из виджета идёт мимо подменяемого `_saveRoots`
  блока: `SavePathFinder.suggest` зовётся статически
  (`saves_section.dart:246`), в тестах его не подменить, а повторное нажатие
  запускает второй обход и второй диалог.
- [x] В строке правила нет `Flexible`: метка и три тега в `Row`
  переполнятся на длинной метке (`saves/rule_tile.dart:54–84`).
- [x] `CurvedAnimation` создаётся в каждом `build` и не освобождается
  (`widgets/fade_indexed_stack.dart:68`): на контроллере, живущем всю
  сессию, остаётся по слушателю на каждую смену раздела. То же, мягче, в
  `widgets/rise_in.dart:61`. Завести один раз полем и освобождать.
- [x] Два определения «активной задачи»: метка в обойме считает по
  `activeTasks` (`bloc/downloads/downloads_state.dart:16`), страница
  загрузок — по-своему, с ошибочными и без очереди
  (`downloads_page.dart:54–56`), и это число уходит в показание «N / max».
  Один геттер в состоянии.
- [ ] Третий слушатель окна: `window_frame.dart:202–262` держит
  `_maximized`, `_fullScreen` и трюк с `_revision` против гонок — при двух
  уже существующих в `services/system/managed_window.dart:39,91`, о чём
  предупреждает собственный комментарий (`window_frame.dart:144–146`).
- [x] Чужой док-комментарий в `speed_field.dart:6–10` (остался от
  `ThemePicker`, а сам `ThemePicker` в `pickers.dart:115` — без описания).

### Этап 2. Тема (P1)

- [ ] `lib/ui/theme/` — папка вместо трёх файлов в корне `lib/ui`:
  `palette.dart`, `typography.dart`, `motion.dart`, `shape.dart`,
  `evaporate_theme.dart` (сборка), `decor_colors.dart` (бывший `AppColors`).
  `theme.dart` остаётся бочкой с экспортами — импорты не меняются. **S**
- [ ] **`EvaporateTypography`** — `ThemeExtension`, собирается из палитры,
  чтобы роль несла и цвет по умолчанию; доступ `context.text.caption`.
  Роли вывести из фактического употребления: `body` 13, `bodyMuted`,
  `bodyStrong` 13/w600, `note` 12.5 muted, `caption` 12 muted, `label` 11.5,
  `path` (моно 12–12.5), `eyebrow` (моно капс), `readoutLabel`, `readout`
  (моно, табличные цифры), `keycap` (Unbounded на клавише), `heroTitle`.
  Затем заменить 184 `TextStyle` по месту. **L**, идёт по папкам.
  Откуда видно, что роли настоящие, — одни и те же стили уже выписаны
  по нескольку раз:
  - пояснение 12.5 + `textSecondary`: `scan_folder_dialog.dart:271,282,291`,
    `action_panel.dart:169,307`, `detail_header.dart:40,63`,
    `restore_dialog.dart:122`, `watched_folders.dart:58`;
  - моно-путь 11.5–13: `rule_tile.dart:88`, `restore_dialog.dart:167`,
    `watched_folders.dart:87`, `scan_folder_dialog.dart:222`,
    `rule_dialog.dart:72`;
  - заголовок строки 13/w600: `rule_tile.dart:58`, `snapshot_tile.dart:84`,
    `watched_folders.dart:48`;
  - строка списка 13 и 11.5 в четырёх диалогах — это работа
    `listTileTheme`, в котором сейчас заданы только цвета (`theme.dart:77`);
  - заголовок игры 24/w700 (`detail_header.dart:29`) — мимо `textTheme`,
    хотя `headlineSmall` настроен ровно для этого;
  - подпись настройки, кегль 13, — 19 раз в `settings/` (`settings_page.dart`,
    `proxy_settings_card.dart`, `gamepad_settings.dart`, `pickers.dart`,
    `speed_field.dart`, `path_setting.dart`, `notification_settings.dart`);
  - у одной роли «пояснение» три разных набора: 12.5 / 1.5
    (`settings_page.dart:418`, `log_card.dart:92`, `effects_card.dart:47`,
    `available_games.dart:48`, `queue_column.dart:291`), 12 / 1.4
    (`proxy_settings_card.dart:272`, `notification_settings.dart:59`) и
    13 / 1.5 (`sync_folder_card.dart:64`, `snapshot_history.dart:43`,
    `bulk_transfer_card.dart:135`);
  - «метка на корпусе» (моно, капс, w700–800, разряд от 0.6 до 2.2):
    `section_heading.dart:56`, `readout_panel.dart:94`,
    `queue_column.dart:254,266`, `app_footer.dart:86`, `top_bar.dart:85`; без
    моно выбиваются `download_activity.dart:236` и `navigation.dart:227`;
  - стиль текста `SegmentedButton` скопирован четырежды (`pickers.dart:41,100,154`,
    `effects_card.dart:82`) — ему место в `segmentedButtonTheme` (`theme.dart:211`).
- [ ] Темы компонентов (по образцу из §2), в порядке числа ветвлений:
  `GlassSurface` (6) → `SpatialBackdrop` и `HardwareGrille` →
  `LauncherActionButton` → `AmbientLight` → `ReadoutPanel`, `SectionCard`,
  панель оболочки (`shell.dart:171`), рейка навигации
  (`navigation.dart:103`), кадр `FeaturedGame` (`:73`), `CoverBackdrop`
  (`:74`), подложка панели инструментов (`toolbar.dart:58`). Итог: `isDark`
  остаётся только в `lib/ui/theme/`. **M**
  Два наблюдения в помощь. Тень панели — одна и та же пара (22/10 ночью,
  8/2 днём) в `navigation.dart:103–104` и `featured_game.dart:73–74`: это
  токен материала `panelShadow`, а не ветвление. И образец уже есть в коде:
  `pulse_dot.dart:30` и `LauncherActionButton` (`common.dart:44,117`)
  спрашивают не «какая схема», а «есть ли у материала ореол / торец»
  (`glow.a`, `depth.a`) — так ветвление по схеме превращается в свойство
  токена.
- [ ] Кант и заливка состояния — одна роль с четырьмя альфами (0.42–0.6):
  `engine_status.dart:38–39,86–89`, `queue_column.dart:82`,
  `top_bar.dart:72,246–249`, `available_games.dart:122–127`,
  `snapshot_history.dart:90–95`; всего в `lib/ui` 41 вызов
  `withValues(alpha:)` с 27 разными числами. Свести к шкале из
  четырёх-пяти ступеней (`tint`, `rim`, `scrim`, `glass`). Цвет состояния
  движка выбирается одинаковым `switch` в `app_footer.dart:80–85` и
  `engine_status.dart:16–21` — в `labels.dart` или в тему. **S**
- [ ] Раскладка — тоже токены: поля 28 (`settings_page.dart:75`,
  `saves_page.dart:47`, `downloads_page.dart:85,96,207`), ширина 1340
  (`downloads_page.dart:79`, `saves_page.dart:53`), высоты 64 / 48 / 40
  (`top_bar.dart:24`, `navigation.dart:92`, `app_footer.dart:30`), подпись
  настройки шириной 220 (11 раз) → `EvaporateLayout` и общий
  `ContentFrame` (центр, предельная ширина, поля). **S**
- [ ] Украшения: `ambientParticleColor(isDark)`, `waveColors(isDark)` и
  ветвления в `library_atmosphere.dart:68,213,235`, `portal_sparks.dart:279`,
  `game_wave.dart:82` — в расширение `EffectsPalette` (`waveColors`,
  `waveAlpha`, `sparkBlend`, `ambientWash`, цвет частиц): выбор по схеме
  делает тема, а не вызывающий. Текст и тени на обложке
  (`game_cover.dart:229,311`, `detail_cover.dart:102`) — в `CoverTheme`. **S**
- [ ] Доопределить темы Material: `textButtonTheme`, `iconButtonTheme`,
  `switchTheme`, `checkboxTheme`, `listTileTheme` (кегль), опасная заливка
  кнопки — вариантом, а не `styleFrom` по месту. **S**
- [ ] Длительности мимо токенов: `nav_tile.dart:66,92,95` (120 мс →
  `motion.instant`), `game_cover.dart:177`, `fade_indexed_stack.dart:14`,
  `liquid_selection.dart:40`, `animated_progress.dart:65`. Радиусы мимо
  токенов: `game_cover.dart:319`, `save_tag.dart:15`,
  `detail_cover.dart:113`, `button_hints.dart:97`. Ширина диалога 560
  выписана в четырёх местах (и 540 в `rule_dialog.dart:56`) — токен
  `dialogWidth`. **S**
- [ ] `lerp`/`copyWith` на 20 полей: либо тест «каждое поле смешивается»
  (перебор через `copyWith`), либо генерация (`theme_tailor`) 💬. **S**

### Этап 3. Виджеты: один файл — один публичный виджет (P1)

Порядок работы над файлом: приватные классы → методы-виджеты → соседи по
файлу. Имена и папки — ниже; после каждого файла вычёркивать его из
списка стража.

**Приватные виджеты (41):**

| Файл | Сейчас | Станет |
|---|---|---|
| `library/featured_game.dart` | `_Art`, `_CompactContent`, `_Eyebrow`, `_Actions`, `_PlaytimeReadout` + метод `_full` | `library/featured/`: `FeaturedArt`, `FeaturedCompactBar`, `FeaturedEyebrow`, `FeaturedActions`, `PlaytimeReadout`, `FeaturedPoster` (из `_full`) |
| `library/game_cover.dart` | `_Art`, `_TitlePlate`, `_StatusBadge`, `_ProgressStrip` + `_tile` (70 строк) | `library/cover/`: `CoverArt`, `CoverTitlePlate`, `CoverStatusBadge`, `CoverProgressStrip`, `CoverFrame` + `CoverFace`. Два `_Art` в двух файлах перестают спорить за имя |
| `library/shots_backdrop.dart` | `_Slideshow`, `_Shot` | `library/featured/`: `ShotsSlideshow`, `ShotFrame` |
| `library/scan_folder_dialog.dart` | `_ScanFolderDialog`, `_Progress`, `_DropArea` + `_list` | `library/scan/`: `ScanFolderDialog`, `ScanProgress`, `ScanDropArea`, `ScannedGamesList` + `ScannedGameTile` |
| `library/add_game_dialog.dart` | `_AddGameDialog`, `_PathPicker` + 3 метода | `library/add/`: `AddGameDialog`, `SourceKindPicker`, `SourceFields`, `StartNowTile`; `PathPickerField` — в `widgets/` |
| `library/toolbar.dart` | `_AddGameButton` + `_arrange`, `_search` | `library/toolbar/`: `AddGameMenuButton`, `ToolbarLayout`, `LibrarySearchField`; соседи `ShelfTabs`, `ShelfButton` — своими файлами |
| `library/saves_section.dart` | `_FindPathsButton` | `library/saves/find_paths_button.dart`; `SavePathsSection` и `SnapshotsSection` — двумя файлами |
| `library/detail/action_panel.dart` | `_SteamShortcutButton`, `_SteamLookupButton` + `_buildRow`, `_primaryActions` (77 строк) | это один виджет с разными ключом занятости, событием и значком → общий `BusyOutlinedButton`; `PrimaryActions` — четыре виджета по веткам `switch`; `DownloadSummary` — своим файлом |
| `library/detail/rating_row.dart` | `_Count`, `_Metacritic` | `library/detail/`: `ReviewCount`, `MetacriticBadge` |
| `library/foil_card.dart` | `_FoilScope` (+ `_FoilMotion`, общий для `FoilCard` и `FoilSurface`) | `library/effects/foil/`: `FoilScope`, `FoilMotion`, `FoilCard`, `FoilSurface` |
| `library/saves/restore_dialog.dart` | 5 методов | `RestoreDialogBody`, `LocalFreshnessNote`, `RestoreTargetList`, `RestoreOptionsForm`, `RestoreDialogActions`; модель `RestoreOptions` — своим файлом |
| `library/saves/*` | `_summary`, `_action`, `_hintRow`, `_footer`, `_absoluteWarning`, локальная `row()` | `SnapshotSummary`; `_action` — это готовый `IconAction`; `SaveHintRow`, `SaveHintsFooter`; общий `InlineWarning`; `LabeledSwitchRow` |
| `library/game_detail.dart`, `game_page.dart` | `_content`, `_wrapHistory` | `GameDetailBody`, `RemoveGameButton`, `BackToLibraryButton` |
| диалоги, собранные внутри методов | `files_section.dart:84–120`, `remove_game_dialog.dart:32–60` | `ExecutablePickerDialog`, `RemoveGameDialog` |
| `shell.dart` | `_Sections` + `_layout`, `_panel`, `_footer` | `shell/`: `AppShell`, `ShellSections`, `ShellPanel`, `ShellFooterStrip` |
| `shell/top_bar.dart` | `_WindowDragArea` + `_brand`, `_actions`, `_windowActions` | `WindowDragArea`, `TopBarBrand`, `TopBarActions` + `ThemeCycleAction` (логика `:170–187`), `WindowActions`; сосед `TopAction` — своим файлом |
| `shell/navigation.dart` | `_QueueBadge` + `_rack` (55 строк), `_button` (58) | `QueueBadge`, `NavigationRack`, `NavigationKey`; `// ignore` на `:170` лечится перестановкой аргументов |
| `settings/settings_page.dart` | 7 методов | `settings/cards/`: `AppearanceCard`, `WindowStartupCard`, `DownloadSettingsCard` (83 строки), `MetadataCard`, `EngineInfoCard`, `SaveSettingsCard` (65) |
| `settings/gamepad_settings.dart` | `_BindingRow`, `_CaptureButtonDialog` + `_status`, `_deadzone` | `GamepadBindingRow`, `CaptureButtonDialog`, `GamepadStatusRow`, `DeadzoneSlider` |
| `settings/proxy_settings_card.dart` | `_Field`, `_Warning`, `_Note` + 3 метода | `SettingTextField`, `ProxyKindPicker`, `ProxyAddressFields`, `ProxyApplyRow`. `_Warning` байт в байт повторён в `notification_settings.dart:71` → общий `WarningNote`; `_Note` — в `settings_page.dart:416`, `log_card.dart:90`, `effects_card.dart:43`, `notification_settings.dart:57` → общий `SettingNote` |
| `settings/pickers.dart` | три публичных виджета | все три — «подпись шириной 220 + `SegmentedButton`» → один обобщённый `SegmentedSetting<T>`; рядом `SettingRow` и `SettingSwitch` (`SwitchListTile` с нулевыми полями выписан 10 раз) |
| `settings/effects_card.dart`, `notification_settings.dart` | `_presets`, `_details`; `_warning`, `_buttons` | `EffectPresetPicker`, `EffectDetails`; `NotificationActions` |
| `saves/sync_folder_card.dart` | `_PackageRow` + диалог в `_pickGame` (62 строки) | `SyncPackageRow`, `PickGameDialog`; правило «совпавшая по названию — первой» (`:212–218`) — чистой функцией в сервисы |
| `saves/snapshot_history.dart` | `_SnapshotRow` + `_summary` | `SnapshotRow`, `SnapshotSummary` |
| `saves/bulk_transfer_card.dart` | `_BulkReportView` + диалог в `_askAboutNewer` | `BulkReportView`, `BulkOutcomeGroup`, `ImportNewerDialog` |
| `saves/saves_page.dart` | `_Heading`, `_readout` | `_Heading` — пустая обёртка из трёх аргументов (`:136–140`): удалить, звать `SectionHeading` по месту, как в `settings_page.dart:79–83`; `SavesReadout` |
| `downloads/downloads_page.dart` | `_Heading`, `_columns`, `_readout` | это другой виджет, с тем же именем: чип движка, перезапуск и логика «замерло» (`:201–203`) → `DownloadsHeading`; `DownloadsColumns`, `DownloadsReadout` |
| `downloads/download_activity.dart` | `_Metric` + `_metrics`, `_amounts` | `DownloadMetric`, `DownloadMetrics`, `DownloadAmounts`; соседи `DownloadHistoryScope`, `DownloadChart` — своими файлами |
| `downloads/task_card.dart` | `_header`, `_actions`, `_stats` | `TaskHeader`, `TaskActions`, `TaskStats`; `_cancel` (`:21`) и `_removeFromQueue` (`queue_column.dart:18`) — один поток с разными строками, хватит одной функции |
| `downloads/queue_column.dart` | 5 публичных виджетов | `QueueList`, `QueuedCard`, `SectionTitle`, `QueueHint` — по файлу. `QueueList` зовёт приватный `column._gameFor` (`:108,161`) → `LibraryState.gameForTask` |
| `downloads/available_games.dart` | `_RemoveButton` | `RemoveGameButton`; соседи `DraggableGame`, `GameChip` — своими файлами |
| `widgets/button_hints.dart`, `animated_progress.dart` | `_HintChip`, `_Hatching` | `HintChip`, `ProgressHatching` (+ `IndeterminateProgress`, `ProgressFill`: `ClipRRect` там повторён дважды) |
| `widgets/liquid_selection.dart` | `_LiquidInkScope` | `LiquidInkScope`; помеха: `LiquidSelectionInk` читает приватные поля чужого `State` (`:233–252`) — нужен публичный интерфейс геометрии только для чтения |
| `widgets/window_frame.dart`, `readout_panel.dart`, `ambient_light.dart` | `_resize`, `_withBars`, локальная `wash` | `WindowResizeZone`, `ReadoutRow`, `AmbientWash`; `WindowControl` и `ReadoutCell` — своими файлами |
| `shell/app_footer.dart`, `downloads/engine_status.dart` | по два публичных | `EngineReadout`; `EngineStatusChip`, `EngineFailure` |
| наведение | `_hovered` в четырёх `State` (`top_bar.dart:218`, `available_games.dart:104,176`, `snapshot_history.dart:73`) | один `HoverBuilder` |

**Методы, возвращающие виджеты (70).** Это те же приватные виджеты, только
без своего `Element`: нет границы перестроения, нет `const`, в дереве
инспектора их не видно. Лидеры: `settings_page.dart` (7; `_downloadsCard` —
83 строки, `_savesCard` — 65) → по карточке на файл в `settings/cards/`;
`library_page.dart` (7: `_heading`, `_toolbar`, `_measuredGrid`, `_grid`,
`_tile`, `_cover`, `_empty`) → `LibraryGrid`, `LibraryGridTile`,
`LibraryEmptyState`; `restore_dialog.dart` (5: `_content`,
`_localFreshness`, `_targetList`, `_options`, `_actions`); по три —
`top_bar.dart` (`_brand`, `_actions`, `_windowActions`), `shell.dart`,
`proxy_settings_card.dart`, `add_game_dialog.dart`, `task_card.dart`
(`_header`, `_actions`, `_stats`). Полный список даёт страж из этапа 0.

Не путать с этим `effects_card.dart:133` `_effects`: он возвращает таблицу
данных (`List<_Effect>`), а не виджеты, — так и надо, таблица вместо
тринадцати выписанных переключателей и есть снижение сложности.

**Файлы-сборники:** `widgets/common.dart` (6 виджетов и 3 функции) →
`launcher_action_button.dart`, `icon_action.dart`, `status_chip.dart`,
`section_card.dart`, `empty_state.dart`, `info_row.dart`, а `showError` /
`showInfo` / `confirm` → `lib/ui/feedback/`; `downloads/queue_column.dart`
(5); по три — `toolbar.dart`, `download_activity.dart`,
`available_games.dart`, `spatial_surface.dart`, `pickers.dart`.

**Повторы, которые вынос обнажит** — их сводят в общие виджеты, а не
копируют по новым файлам:

- `play_button.dart` — пустая обёртка над `LauncherActionButton` (`:12–16`),
  удалить;
- подпись хода загрузки: `switch` в `_ProgressStrip`
  (`game_cover.dart:289–297`) и в `CoverProgress`
  (`detail/detail_cover.dart:80–87`) совпадают побайтово;
- условие «задача есть и не завершена» выписано в пяти местах
  (`game_cover.dart:59,77`, `game_detail.dart:42`, `action_panel.dart:42`,
  `detail_cover.dart:28`), хотя у задачи уже есть `isFinished`
  (`models/download_task.dart:70`);
- тонированная плашка: `save_tag.dart:14`, `rating_row.dart:144` и
  `StatusChip` (`common.dart:228`) — три реализации с альфой 0.13 / 0.14 →
  один `TonedChip`;
- карточка-строка: `rule_tile.dart:31–38`, `snapshot_tile.dart:42–49`,
  `watched_folders.dart:31–38` → `InsetTile`; «колодец» поиска и полок —
  `toolbar.dart:119–125` и `:246–252`;
- предупреждение со значком (12–12.5, `warning`, высота 1.4) —
  `action_panel.dart:65`, `restore_dialog.dart:133,153`,
  `rule_dialog.dart:138`, `scan_folder_dialog.dart:369` → `InlineWarning`;
- кружок занятости 14×14 — в шести местах → `BusySpinner`;
- `DottedBorderBox` (`drop_overlay.dart:56`) рисует сплошную рамку — имя
  обещает другое → `DropFrame`.

Приватные `CustomPainter` виджетами не являются и под правило не попадают,
но `portal_sparks.dart` (536 строк: виджет, художник, атлас, пачка искр,
отрисовщик, геометрия `edgeAt` на 68 строк) стоит разложить в
`library/effects/portal/` ради проверяемости частей. Сами украшения
(`portal_sparks`, `particle_field`, `cover_drops`, `game_wave`, `hero_sweep`,
`foil_card`, `library_atmosphere`) — в `library/effects/`: папка `library/`
сейчас мешает их со страницами.

### Этап 4. Состояние (P2)

- [ ] **`BlocObserver`** → `AppLog`: ошибки всегда, переходы — в отладке. **S**
- [ ] **Общее у блоков — примесями.** `_notice`, `_withBusy`,
  `_finishBusy`, `_l`/`_localizations`, `_notifySystem`, отложенная запись с
  дожиданием в `close()` повторены в трёх блоках почти дословно. Десяток
  обработчиков повторяет «взвести → `try` → погасить + сообщение» — заменить
  помощником, у которого гашение в `finally`:

  ```dart
  Future<void> _busyWhile(Emitter<S> emit, String key,
      Future<String?> Function() work) async { … }
  ```
  **M**
- [ ] **`UpdateBloc`** вместо состояния в `AboutCard`
  (`about_card.dart:42–204`: `_busy`, `_message`, `_isError`, `_found`,
  `_updating` — при правиле «свой `_busy` в экранах не нужен»). События:
  `UpdateCheckRequested`, `UpdateInstallRequested`, `UpdateProgressed` (от
  загрузчика — внешний источник). Уровень приложения: сейчас проверка при
  запуске (`main.dart:326`) и проверка по клавише — две разные, и найденное
  на старте карточка не знает. **M**
- [ ] **`AddGameBloc`** вместо `_AddGameDialogState` (`_busy`, `_error`,
  проверки броском строк, ожидание появления игры в чужом состоянии —
  `add_game_dialog.dart:249–262`). **M**
- [ ] **`LibraryViewBloc`** — запрос и полка из `_LibraryPageState`
  (`library_page.dart:45–46`), отбор и сортировка (`:444–491`) — чистыми
  функциями рядом с блоком, под тестом; событие набора — с задержкой. В
  `State` остаются наведение, фокус, прокрутка. **M**
- [ ] **`ScanBloc`** для окна поиска игр: `ScanSession` — внешний источник,
  как движок загрузок, то есть блок по правилу самого `CLAUDE.md`. События:
  `ScanStarted`, `ScanNarrowed(dir)`, `ScanFolderDropped(paths)` (забирает
  `Directory.exists` из `scan_folder_dialog.dart:106`), `ScanStopRequested`,
  `ScanSessionChanged`, `ScanGameToggled(dir, on)`. Сейчас выбранное
  пересобирается на каждую строку списка (`:81–88`), а в библиотеку уходит
  N событий `GameAdded` (`:118–133`) — вместо них одно `ScannedGamesAdded`.
  Признак «тащат над окном» остаётся в `State`. **M**
- [ ] **`RestorePreviewBloc`** вместо `SaveFreshnessCubit`: состояние
  `{freshness, targets, newer}`. Сейчас правило «снимок новее здешних
  сейвов» живёт в виджете (`restore_dialog.dart:39–41`), а `previewTargets`
  зовётся из `build` через `context.read<SavesBloc>().saveManager`
  (`:59–62`). Галочки «резервная копия» и «очистить» — состояние формы,
  остаются в `State`. **S**
- [ ] **`RuleFormBloc`** для диалога правила: метка, шаблон, развёрнутый
  путь, переносимость, `canSave`. Сейчас превью пересчитывается в `build`
  через `setState(() {})` на каждое нажатие клавиши (`rule_dialog.dart:71`),
  а проверок нет вовсе (см. пустой шаблон и занятую метку в этапе 1).
  Контроллеры текста остаются в `State`. **S**
- [ ] В `SavesBloc` — события вместо логики в `saves_section.dart`:
  `SavePathSuggestionsRequested(game)` с ключом занятости и результатом в
  уже существующие `saveHints`; `SnapshotImportInspectRequested(path, game)`
  с полем `pendingImport` (сейчас `inspectPackage` и `try/catch` в виджете,
  `:392–417`). В `LibraryBloc` — `GameExecutableDetectRequested(id)` и
  `GameFolderOpenRequested(id)`. **M**
- [ ] **`LogBloc`** для `LogCard` (`log_card.dart:29–50`: `_lines`, свой
  `_busy`, чтение и очистка). События `LogShowRequested`,
  `LogClearRequested`; побочная выгода — тесты без `runAsync`. **S**
- [ ] **`ButtonCaptureBloc`** для диалога захвата кнопки
  (`gamepad_settings.dart:232–247`): поток нажатий геймпада — внешний
  источник. События `CaptureStarted(action)`, `RawButtonPressed(button)`,
  `CaptureCancelled`; на время захвата блок глушит действия в
  `GamepadService` — это и закрывает ошибку из этапа 1. **S**
- [ ] **`WindowBloc`** вместо состояния в `AppWindowFrame`
  (`window_frame.dart:202–262`): события от `WindowListener`
  (`WindowMaximized`, `WindowUnmaximized`, `FullScreenEntered`,
  `FullScreenLeft`) и `WindowSizeToggled` от клавиши. Последовательная
  обработка убирает трюк с `_revision`, а слушатель окна снова один. **M**
- [ ] **`FilesDropped(paths)`** в `LibraryBloc` вместо логики в
  `GameDropTarget`: разбор, занятость, `Notice`. Игры из `.torrent`
  библиотека публикует потоком, как `gameExits`, а `DownloadsBloc`
  подписывается и сам шлёт себе `DownloadRequested` — зависимость остаётся
  односторонней, а ожидание `library.stream.firstWhere` исчезает из обоих
  мест, где оно скопировано. **M**
- [ ] **`ProxyFormBloc`** (`proxy_settings_card.dart:46–56`): сейчас неверный
  порт молча подменяется старым (`:50`), диапазон не проверяется, строка
  адреса показывает сохранённое, а не набранное (`:176`), `showInfo` идёт
  мимо `Notice` (`:55`). Состояние `{draft, portError, dirty}`; разбор —
  чистой функцией `ProxySettings.fromForm` под тестом. **S**
- [ ] Производное — геттерами состояния, а не в `build`:
  сортировка всех снимков на каждую пересборку (`saves_page.dart:34–38,89–98`),
  подсчёты на странице загрузок (`downloads_page.dart:54–57`), отбор
  доступных игр (`available_games.dart:21–30`). Пересчёт места в очереди в
  индекс движка (`queue_column.dart:139–152`) — знание движка внутри
  виджета; событие `DownloadReordered(id, beforeId)` его забирает. **S**
- [ ] Разделы — перечислением `AppSection`, а не числами: сейчас два
  параллельных списка и магическое `_downloadsSection = 1`
  (`navigation.dart:48,60–71`), `sectionCount = 4` в блоке и `section != 0`
  в оболочке. Блок остаётся блоком. **S**
- [ ] `DownloadHistoryBloc` — см. §3.
- [ ] **`DownloadsBloc` не проверить без торрентов.** Он создаёт
  `DtorrentEngine` сам и держит по конкретному типу
  (`downloads_bloc.dart:43,100`). Одним параметром конструктора это не
  лечится: блок зовёт `verify`, `torrentPathFor`, `reorder`, `setProxy`,
  `pumpQueue`, `applyLimits`, которых в «узком» `DownloadEngine` нет, —
  контракт надо дорастить до того, чем блок пользуется. Цена вопроса видна
  в покрытии: из 13 событий тесты шлют два; запрос загрузки, пауза,
  возобновление, отмена и перестановка не исполняются ни разу (файл покрыт
  на 59 %). После правки — `FakeDownloadEngine` и тесты на эти пути. **M**
- [ ] Подписки на состояние целиком: `context.watch<…>().state` в 19 местах
  (`library_page.dart:120–123` перестраивает сетку на любой чих `busy` и
  `savePathsProgress`). Заменить на `select` по нужным полям. **S**
- [ ] **`GameRepository`** 💬 — единственный владелец списка игр и файла
  `library.json`; правка — функцией от текущего значения
  (`patch(id, (game) => …)`). `LibraryBloc`, `DownloadsBloc`, `SavesBloc`
  зависят от него, а не друг от друга — так советует и документация bloc
  («связывать блоки через доменный слой»). Уходят: слияние в
  `_onGameUpdated`, трюк `SavesBloc._updateGame`, ожидание игры в диалоге
  добавления. Делать после намеренческих событий из этапа 1. **L**
- [ ] `LibraryBloc` пишет файлы сам (обложки, кадры —
  `library_metadata.dart:175–259`). Вынести в `CoverCache` и
  `GameMetadataFetcher`: `_onSteamLookup` (94 строки, сложность 21) станет
  «спросить сервис → положить в состояние». **M**
- [ ] `FocusNode` внутри `NavigationBloc` — ресурс UI в блоке. Перенести в
  оболочку, а запрос фокуса подавать одноразовым сигналом по образцу
  `Notice.seq`. Блок остаётся блоком. **S**
- [ ] События с неполным `props` (`GameUpdated` сравнивается по четырём
  полям из двадцати семи). Если события никто не сравнивает — убрать у них
  `Equatable`; иначе — полные `props`. **S**

### Этап 5. Когнитивная сложность (P1)

Рецепты: ранний выход вместо вложенности; конвейер именованных шагов;
таблица вместо ветвлений; результат-значение вместо исключения для потока
управления; один уровень абстракции на функцию.

| Сложн. | Строк | Где | Что сделать |
|---|---|---|---|
| 22 | 106 | `services/saves/bulk_transfer.dart:136` `importAll` (и `:63` `exportAll`) | `_importOne(package) → BulkEntry` на ранних выходах, зеркально `_exportOne(game)`; шесть накопителей убрать — `BulkReport.count()` уже есть (`models/bulk_report.dart:54`), сообщение строить из отчёта |
| 22 | 61 | `services/saves/restore_transaction.dart:10` `_buildRestorePlan` | конвейер: `_payloadEntries()` → `_destinationFor(target, parts)` → `_PlanBuilder.add()`; строитель сам держит `destinations`, `filesPerRule`, `bytes` и сам бросает |
| 21 | 94 | `bloc/library/library_metadata.dart:31` `_onSteamLookup` | сеть и файлы — в сервис (этап 4) |
| 16 | 71 | `services/launch/game_launcher.dart:70` `launch` | `_resolveExecutable(game)` (все отказы и «бандл → бинарник») → один `Process.start` → `_track()`; сейчас развилка по системе стоит дважды (`:82,99`) |
| 15 | 46 | `ui/widgets/game_drop_target.dart:88` `_handleDrop` | уходит в блок событием `FilesDropped` (этап 4) |
| 15 | 43 | `services/launch/vdf.dart:70` `_tokens`, `:27` `parse`; `binary_vdf.dart:65` | `_unescape(char)` выражением `switch`; `_VdfBuilder{open, close, pair}`; запись значения — `switch (value) { Map m …, String s …, int i … }` вместо цепочки `if is` |
| 15 | 38 | `services/launch/steam_shortcuts.dart:355` `_putArtwork`, `:421`, `:127` | таблица `SteamArtwork.files(id)` и один цикл; `sync*`-итератор сегментов JPEG + `firstWhere`; разбор заголовков картинок (`:396–459`) — в свой файл |
| 14 | 72 | `bloc/library/library_metadata.dart:497` `_onSavePathsLookup` | `_busyWhile` + `done()` в `finally` |
| 13 | 72 | `services/saves/save_manager.dart:415` `_restoreFrom`; `:139`, `:219` | `_validManifest()` (общий с `:570–575`), `_resolveTargets(game, rules)`, `_backupBeforeRestore()`, commit; в `_materialize` флаг `complete` → `on Object { убрать; rethrow }` |
| 12 | 43 | `services/download/engine_queue.dart:66` `_launch`, `:20` | `_modelFor()`, предикат `_stillWanted(managed, generation)` вместо условия в четыре строки (`:79–84`), `_startTask()` |
| 12 | 41 | `services/launch/executable_finder.dart:71`, `:143` | очки запуска — таблицей `{система: {расширение: очки}}`; `_visitDirectory` / `_evaluateFile` |
| 12 | 31 | `services/launch/windows_installs.dart:62` `installed` | `_query(exec, root)` отдаёт пустой список при сбое — дальше плоско: без повторов и сортировка |
| 12 | 27 | `services/saves/ludusavi_catalog.dart:126` `find` | ленивый индекс `Map<int, LudusaviEntry>` вместо линейного прохода; поиск по названию — общим `bestBy` с `steam_catalog.dart:291–300` |
| 10 | 64 | `services/system/update_download.dart:110` `_prepare`, `:424` | шаги `_fetchPart → _verify → _promote → _stage` с локальным `report(phase)`; `_httpFetch` пустить через готовый `_open` (`:403`) |
| 10 | 27 | `core/save_path_template.dart:117` `collapse` | корни сортируются на каждый вызов, а зовут её в циклах обхода → `static final _rootsBySpecificity` |
| — | 72 | `input/input_scope.dart:188` `build`, `:118` `_move` | пять `Intent`-классов и пять `CallbackAction` (`:217–252`) дублируют `switch` в `_handleAction` → один `NavActionIntent(action)` и `const Map<ShortcutActivator, NavAction>`; `build` сжимается до полутора десятков строк — и клавиатура наконец сводится к `NavAction`, как обещает `CLAUDE.md` |
| 12 | 32 | `bloc/library/library_bloc.dart:359` `_onGameRemoved` | три удаления — тремя методами; «своё ли это» — одной проверкой |
| 9 | 44 | `bloc/library/library_bloc.dart:306` `_onGameUpdated` | исчезает целиком (этап 1) |
| 10 | 68 | `ui/library/portal_sparks.dart:136` `edgeAt` | таблица из восьми сегментов контура и один цикл; `advance` отдаёт рождение искр в `_emit`, `paint` делится на обод и искры |
| 11 | 29 | `ui/library/library_atmosphere.dart:89` `_tick` | общий шаг часов — один на три копии (этап 1, риски) |
| 4 | 53 | `ui/library/scan_folder_dialog.dart:246` | три ветки с одним стилем: сначала вычислить текст, потом один `Text`; тернарники ради побочного эффекта (`:206–212`) → `toggle` в блоке |

**Классы-комбайны** — сложность не функции, а файла:

- [ ] `SaveManager` (756 строк + 384 в `part`). Обход «правило → путь»
  повторён четырежды (`save_manager.dart:159,271,436,506`). Выделить
  `EvsavePackage` (открыть, манифест, правила, разбор имён записей),
  `SaveCollector` (сбор файлов и `lastLocalChange`), `RuleMatcher`
  (`_matchLocalRule` + `previewTargets`), а `RestoreTransaction` сделать
  настоящим классом вместо расширения. Сам `SaveManager` остаётся фасадом
  под `store.guard`. **L**
- [ ] `DtorrentEngine` с четырьмя `part`-файлами: состояние задачи — в
  шести полях (`started`, `pausedByUser`, `error`, `task`, `model`,
  `generation`), правится в шести местах, а `_ManagedDownload` зовёт
  обратно `engine._persist()` (`managed_download.dart:95`). Перечень
  состояний слота с методами-переходами и чистая `DownloadQueue` — это же
  и лечение «вечной ошибки» из этапа 1. **L**
- [ ] `UpdateDownload` (466 строк): транспорт (`:326–465`), проверка и
  распаковка (`:223–319`) — три класса. `SteamShortcuts` (460): профили,
  запись списка, витрина, заголовки картинок. **M**

**Дублирование:**

- [ ] Шесть самодельных HTTP-GET (`steam_catalog.dart:204,423`,
  `update_check.dart:224`, `ludusavi_catalog.dart:154`,
  `update_download.dart:326,424`), выбор «прокси или напрямую» — дважды,
  прореживание хода загрузки — трижды → `HttpFetcher` и `ProgressThrottle`. **M**
- [ ] `_match` и `_normalize` названий: `save_path_finder.dart:147,167` ≡
  `save_activity_watch.dart:227,245`, третья копия нормализации — в
  `release_name.dart:142`. Проверка манифеста — `save_manager.dart:422` ≡
  `:570`; сборка `ScannedGame` — `library_scanner.dart:198` ≡ `:264`. **S**
- [ ] В тестируемости мешает `AppLog.instance`: сервисы зовут его напрямую
  (`update_download.dart:102`, `update_installer.dart:96,124,143,165`,
  `proxy_http_overrides.dart:48`), и запись в журнал не проверить без
  правки глобала (а `update_install_test.dart:544,688` ставит его и не
  возвращает). Передавать функцией, как уже передаётся `L Function()`. **S**

Длинные `build` (глубина дерева 9–11) лечатся этапом 3:
`rule_tile.dart:24` (83 строки), `sync_folder_card.dart:24` (87),
`log_card.dart:59` (84), `rule_dialog.dart:48` (78),
`library_page.dart:118` (78), `downloads_page.dart:45` (72).
`main()` — 105 строк при сложности 2: это список шагов, он читается;
достаточно вынести сборку блоков в `AppServices.bootstrap(paths)`.

### Этап 6. Модели (P3)

Цена одного нового поля сегодня: у `Game` — шесть мест правки, у
`AppSettings` — семь, у флага эффекта — десять. «Забыли поле» уже случилось
дважды: `SteamGame.merge` без кадров и слияние в `_onGameUpdated` без оценки.

- [ ] `Game` — 27 полей в одном классе; `copyWith` на 63 строки. Разложить
  на значения по образцу уже существующего `GameRating`: `GameMetadata`
  (appid, обложки, кадры, описание, оценка, маркер попытки),
  `SaveDiscovery` (шаблоны базы, найденные пути, маркер), `DownloadLink`
  (источник, задача, infohash, размер, ошибка), `PlayStats`. На диске формат
  прежний: каждая часть читает свои ключи из общей карты, `toJson`
  разворачивает `...part.toJson()` — ни пакетов, ни миграции. И это не
  только про чтение кода: событие, правящее `DownloadLink`, физически не
  сможет затереть `GameMetadata`. **M**
- [ ] Эффекты в `AppSettings` — `enum LibraryEffect(jsonKey, defaultOn)` и
  `Set<LibraryEffect>` вместо тринадцати булевых полей, выписанных семь раз
  в `app_settings.dart` и трижды в `effect_preset.dart:35–85`: `copyWith`,
  `toJson`, `fromJson`, `props` и наборы становятся циклами, набор —
  литералом множества. Старые ключи читаются как раньше. Остальное — в
  группы `Appearance`, `StartupSettings`, `SaveAutomation`. **M**
- [ ] Равенство. У `Game`, `SaveProfile`, `SavePathRule`, `SaveSnapshot`,
  `SnapshotBlob`, `GamepadStatus`, `GamepadBinding` нет `==` (`Equatable`
  уже в зависимостях). Следствия: `LibraryState.props` сравнивает игры по
  ссылке, и `copyWith` с теми же значениями даёт «новое» состояние и
  перестройку страницы; `AppSettings ==` по полю раскладки геймпада — тоже
  по ссылке; `_recheckDevices` (`gamepad_service.dart:104`) раз в секунду
  кладёт равный `GamepadStatus`, и слушатели (`app_footer.dart:47`,
  `gamepad_settings.dart:97,273`) перестраиваются раз в секунду. **S**
- [ ] Стражи вместо генерации кода: на каждую модель — «все поля не по
  умолчанию → `fromJson(toJson(x))` равно `x`» и «`copyWith()` без
  аргументов равно исходному»; у `SaveSnapshot.copyWith`
  (`save_snapshot.dart:54`) нечем сбросить `note`. **S**
- [ ] Слои: `models/app_settings.dart:2,4` тянет `material` (ради
  `ThemeMode`) и `input`; `models/save_snapshot.dart:1` импортирует сервис. **S**
- [ ] `GamepadService`: `dispose` (`:253`) закрывает контроллеры раньше, чем
  гаснут таймеры асинхронного `stop()`, — возможен `add` в закрытый поток;
  при быстром «выкл → вкл» раскладки `start()` видит ещё не обнулённую
  подписку (`:73` против `:131`), и геймпад остаётся выключенным. Блок
  здесь не нужен: сервис — преобразователь потока, `NavAction` уже событие. **S**

### Этап 7. Тесты, документы, CI (P3)

- [ ] `README.md`, раздел «Состояние» (`:426–454`), отстал от кода: блоков
  назван четыре (без `SavesBloc`), счёт событий устарел, а обещание «в
  экранах нет ни `bool _busy`, ни `try/catch`» не сходится с
  `about_card.dart`, `add_game_dialog.dart` и `log_card.dart`. После этапа 4
  обещание станет правдой; счёт блоков поправить сразу. **S**
- [ ] `test/` — 98 файлов (около 940 тестов, 21,6 тыс. строк) одной плоской
  папкой. Разложить по слоям, зеркалом `lib/`: `test/bloc/`,
  `test/services/saves/`, `test/ui/library/` … — найти тест к файлу станет
  делом секунды. Стражи — в `test/guards/`. **S**, механически
- [ ] Общее тестов — в `test/support/`: `waitFor` со сборкой блоков и
  `tearDown` скопированы примерно в десять файлов (и с разными таймаутами —
  5 и 10 с), опрос «`runAsync` + `pump`» — в четыре, обвязка `MaterialApp`
  написана 42 раза. Нужны `BlocFixture`, `pumpUntil`, `hostWidget`. Пять
  блок-тестов создают `SavesBloc` без `saveRoots`
  (`save_conflict_test.dart:32`) — по умолчанию туда попадают настоящие
  «Документы». **M**
- [ ] Кандидаты во флаки — положительная проверка после фиксированной
  паузы: `drop_import_test.dart:178,202,224,245` (300 мс),
  `cover_backdrop_test.dart:82`. `fake_async` уже транзитивен — перенести в
  dev-зависимости 💬. **S**
- [ ] 237 `find.text('русская строка')` против 11 через `L`: любая правка
  формулировки в ARB ломает тесты. Искать по ключу локализации или по
  `ValueKey`. 52 названия тестов написаны по-английски (девять файлов,
  например `library_effects_test.dart`) — против правила проекта. **M**
- [ ] `color_palette_test.dart:30–93` — детектор изменений: дублирует
  константы и формулу `hashCode % 360`; проверять свойства (устойчивость,
  попадание в якоря), а не числа. **S**
- [ ] Не покрыто вовсе: `main.dart` и `system_notification_service.dart`
  (их нет в `lcov`), `suggestions_dialog.dart` (0 %), `drop_overlay.dart`
  (4 %), `sync_folder_card.dart` (18 %), `engine_limits.dart` (13 %),
  `saves_bulk.dart` (51 %). `check_coverage.dart:5–31` считает только
  загруженные файлы — непокрытый файл не входит в знаменатель; считать
  отсутствующие как ноль. Пороги в коде — 78 / 79 / 89, в `CLAUDE.md`
  записаны устаревшие 74 / 77 / 88; запас по «ядру и сервисам» — 80,2 при
  пороге 79, меньше заявленных двух-трёх пунктов. **S**
- [ ] Страж имён артефактов ищет `contains` по всему тексту `ci.yml`, а
  `-macos.zip` есть и в комментарии (`ci.yml:169`): переименуй файл в самой
  команде (`:179`) — тест пройдёт. Искать в строке команды. **S**

CI:

- [x] `permissions: contents: read` на уровне `ci.yml` (сейчас права заданы
  только у `release`, `:318`) и `timeout-minutes` каждому заданию:
  зависший ввод-вывод в `testWidgets` — это до шести часов на трёх
  раннерах. **S**
- [ ] Сборка идёт только на теге (`ci.yml:138–140`), а тесты не
  компилируют ни раннеры, ни CMake, ни шейдер `drops.frag`, ни
  `installer.iss`: сломанная сборка обнаружится в день релиза. Собирать по
  расписанию или при изменении `windows/`, `linux/`, `macos/`, `assets/`,
  `pubspec.*`. **S**
- [ ] `flutter pub get --enforce-lockfile` (`:58,101`); экшены — по SHA, а
  не по тегу (`:28,50,125,332`; `subosito/flutter-action` сторонний и
  участвует в релизной сборке); `--test-randomize-ordering-seed`. **S**
- [ ] `build-linux` на `ubuntu-latest` (`:191`): смена образа молча поднимет
  минимальную glibc у пользователей — закрепить версию. `choco install
  innosetup` без версии (`:282`). **S**
- [ ] `release` ставит весь Flutter ради одного `dart run` (`:326`), хотя
  `analyze` тот же скрипт уже запускал (`:81`) — передать `notes.md`
  артефактом. **S**

Локализация и `pubspec`:

- [ ] Ни одного ICU-плюрала: «{count} файлов», «{count} устройства»
  (`app_ru.arb:835,853`), в английском — «1 files». Стража подстановок
  (`localization_test.dart:55`) при этом придётся научить ICU. У 536 ключей
  одно `description` — переводчику не хватает контекста. **M**
- [ ] `cupertino_icons` и `collection` не используются (ноль обращений в
  `lib`). В `pubspec.yaml` остались шаблонные английские комментарии
  (`:3–19`, `:124–153`), нет `flutter:` в `environment`. **S**

---

## 5. Порядок

1. **Сначала то, что грозит данным и главной функции** (этап 1, верх
   списка): пустой шаблон правила, симлинки при обновлении на macOS,
   одинаковые метки правил, уборка хранилища снимков, потерянное обновление
   в `GameUpdated`. Каждое — малым коммитом с тестом, который без правки
   падает. Мелкие — `merge` без кадров, `StateError` в наборах эффектов,
   `chmod` — попутно: они на час каждое.
2. Этап 0 (стражи) — параллельно с первым: он ничего не ломает и сразу
   останавливает рост нарушений.
3. Этап 2 до этапа 3: выносить виджеты лучше уже с `context.text` и темами
   компонентов, иначе каждый файл придётся открывать дважды.
4. Этап 3 — по папкам, каждая папка отдельным коммитом, список стража худеет.
5. Этап 4: сначала намеренческие события (они в этапе 1), затем
   внедряемый движок в `DownloadsBloc` с тестами, потом блоки экранов,
   `GameRepository` последним.
6. Этапы 5–7 — по мере того, как рядом идёт другая работа; исключение —
   `permissions` и `timeout-minutes` в CI: это пять минут, сделать сразу.

После каждого шага — ворота из `CLAUDE.md`: `dart format`, `flutter
analyze`, `flutter test` (полный прогон и без `| tail`: он съедает код
возврата). Вынос виджета поведение не меняет и нового теста не требует;
новый блок — требует. При разборе обработчиков блоков помнить про
микрозадачи: условие «делать ли шаг» остаётся на месте вызова, а не
прячется в `async`-метод, — тесты читают состояние сразу после `waitFor`.

## 6. Чего в плане нет намеренно

- перевода `NavigationBloc` на Cubit — решено оставить блоком;
- блока для `GamepadService` и `InputScope`: сервис — преобразователь
  потока с мимолётным состоянием, `NavAction` уже событие, а `InputScope`
  живёт фокусом и `BuildContext`;
- смены формата `.evsave` и замены зависимостей;
- `bloc_test` и `mocktail`: тесты здесь интеграционные — связанные блоки,
  настоящий диск, ожидание предиката; `expect: [состояния]` привязал бы их
  к числу `emit` и к `Notice.seq`. Общий `BlocFixture` даст больше;
- генерации кода для моделей (`freezed`, `json_serializable`): стражи на
  `copyWith` и `toJson` дают то же без новой сборочной ступени; вернуться к
  вопросу, если моделей станет больше;
- платного DCM: те же правила (сложность, вложенность, «не возвращать
  виджеты из методов») закрываются своими стражами в духе уже существующих.
