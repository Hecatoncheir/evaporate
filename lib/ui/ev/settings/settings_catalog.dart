import 'package:flutter/material.dart';

import '../design/appearance.dart';
import '../design/effects.dart';
import '../design/theme.dart';
import '../glass/glass_lens.dart';
import '../sound/ev_sound.dart';
import '../widgets/ev_controls.dart';
import '../widgets/ev_icon.dart';
import '../widgets/ev_surfaces.dart';
import 'ev_settings_widgets.dart';
import 'settings_data.dart';
import 'settings_search.dart';
import 'sound_settings.dart';

/// Из чего собираются разделы: модели, которые правят настройки, и то,
/// что выводится из других разделов.
typedef EvSettingsSources = ({
  EvAppearance appearance,
  EvEffects? effects,

  /// Звуковой слой окна.
  EvSound sound,
  EvSettings settings,
  List<EvDrive> drives,

  /// Ваш рейтинг раздачи — из профиля: «2,41».
  String ratio,

  /// Облако сохранений: занято и всего, ГБ.
  (double, double) cloud,

  /// Который час — точка над расписанием.
  int hour,
});

/// Строка с сегментами: подписи сегментов тоже ищутся.
EvSettingRow _segments<T extends Object>(
  String title,
  String detail,
  Map<T, String> items,
  T Function() value,
  ValueChanged<T> onChanged,
) => EvSettingRow(
  title: title,
  detail: detail,
  words: items.values.toList(),
  control: (_) =>
      EvSegmented<T>(items: items, value: value(), onChanged: onChanged),
);

/// Строка с выбором из [EvSettings] по ключу.
EvSettingRow _choice(
  EvSettings s,
  String key,
  String title,
  String detail,
  List<Object> options, {
  String Function(Object)? label,
}) => _segments<Object>(
  title,
  detail,
  {for (final o in options) o: label?.call(o) ?? '$o'},
  () => s.choice<Object>(key),
  (v) => s.choose(key, v),
);

EvSettingRow _switch(
  String title,
  String detail,
  bool Function() value,
  ValueChanged<bool> onChanged,
) => EvSettingRow(
  title: title,
  detail: detail,
  control: (_) =>
      EvSwitch(value: value(), semanticLabel: title, onChanged: onChanged),
);

EvSettingRow _flag(EvSettings s, String key, String title, String detail) =>
    _switch(title, detail, () => s.on(key), (v) => s.toggle(key, v));

EvSettingRow _chip(
  String title,
  String detail,
  String value, {
  bool hot = false,
}) => EvSettingRow(
  title: title,
  detail: detail,
  words: [value],
  control: (_) => EvChip(value, hot: hot),
);

/// Десять разделов, которые можно назвать вслух.
List<EvSettingSection> evSettingsCatalog(EvSettingsSources src) {
  final a = src.appearance;
  final fx = src.effects;
  final s = src.settings;
  return [
    EvSettingSection(
      id: 'look',
      title: 'Облик',
      icon: EvIcons.settings,
      panels: [
        EvSettingPanel(
          label: 'Тема оформления',
          glowCorner: true,
          body: (_) => EvSkinCards(value: a.skin, onChanged: (v) => a.skin = v),
          rows: [
            _choice(
              s,
              'density',
              'Плотность интерфейса',
              'Влияет на высоту строк и размер обложек',
              const ['Плотно', 'Обычно', 'Просторно'],
            ),
            _segments<EvGeometry>(
              'Максимальный радиус',
              'По умолчанию 8 px — приборная геометрия. Точки и мелкие чипы '
                  'не меняются: радиус и так режется до половины стороны',
              {for (final g in EvGeometry.values) g: g.label},
              () => a.geometry,
              (g) => a.geometry = g,
            ),
            _chip(
              'Язык интерфейса',
              'Названия игр остаются как в раздаче',
              'Русский',
              hot: true,
            ),
          ],
        ),
      ],
    ),
    if (fx != null) _effects(fx),
    evSoundSection(src.sound),
    EvSettingSection(
      id: 'lib',
      title: 'Библиотека',
      icon: EvIcons.library,
      panels: [
        EvSettingPanel(
          label: 'Где лежат игры',
          body: (_) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final d in src.drives) ...[
                EvDriveRow(drive: d),
                const SizedBox(height: 9),
              ],
              const SizedBox(height: 3),
              const EvMiniButton(
                label: 'Добавить папку',
                icon: EvIcons.folder,
                onPressed: null,
              ),
            ],
          ),
          rows: [
            _flag(
              s,
              'scan',
              'Сканировать при запуске',
              'Ищет новые игры в папках выше · 1–2 секунды',
            ),
            _choice(
              s,
              'covers',
              'Обложки',
              'Если в раздаче нет картинки — рисуем свою',
              const ['Из раздачи', 'Генерировать', 'Без обложек'],
            ),
          ],
        ),
      ],
    ),
    EvSettingSection(
      id: 'net',
      title: 'Загрузки',
      icon: EvIcons.download,
      panels: [
        EvSettingPanel(
          label: 'Расписание скорости',
          note:
              'Нажмите или проведите по часам. Янтарные — без ограничения, '
              'серые — предел ${EvSettings.limitMb} МБ/с.',
          body: (_) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EvSchedule(hours: s.schedule, now: src.hour, onHour: s.setHour),
              const SizedBox(height: 12),
              EvScheduleLegend(now: src.hour),
            ],
          ),
          rows: [
            _chip(
              'Предел приёма',
              'Действует в серые часы',
              '${EvSettings.limitMb} МБ/с',
            ),
            _choice(
              s,
              'slots',
              'Одновременных загрузок',
              'Больше трёх — диск становится узким местом',
              const [1, 2, 3, 5],
            ),
            _chip(
              'Порт входящих',
              'UPnP · проброс подтверждён 2 минуты назад',
              '${EvSettings.port}',
              hot: true,
            ),
            _flag(
              s,
              'encryption',
              'Шифрование протокола',
              'Требовать у всех пиров',
            ),
            _choice(
              s,
              'afterDownload',
              'После докачки',
              'Проверка целостности всегда обязательна',
              const ['Установить', 'Спросить', 'Ничего'],
            ),
          ],
        ),
      ],
    ),
    EvSettingSection(
      id: 'seed',
      title: 'Раздача',
      icon: EvIcons.seed,
      panels: [
        EvSettingPanel(
          label: 'Сколько отдавать',
          rows: [
            _choice(
              s,
              'seedLimit',
              'Раздавать до рейтинга',
              'Ваш текущий — ${src.ratio}. Ниже 1.0 рой перестаёт вас любить',
              EvSeedLimit.values,
              label: (o) => (o as EvSeedLimit).label,
            ),
            _chip(
              'Ограничивать отдачу в игре',
              'Чтобы раздача не ела пинг',
              '${EvSettings.inGameUploadMb} МБ/с',
            ),
            _flag(
              s,
              'stopSeeding',
              'Останавливать раздачу при запуске',
              'Полностью, а не по лимиту',
            ),
            _flag(
              s,
              'friendsUnlimited',
              'Раздавать друзьям без ограничений',
              'Лимит не действует на тех, кто у вас в друзьях',
            ),
          ],
        ),
      ],
    ),
    EvSettingSection(
      id: 'sv',
      title: 'Сохранения',
      icon: EvIcons.saves,
      panels: [
        EvSettingPanel(
          label: 'Облако и защита',
          rows: [
            _flag(
              s,
              'cloud',
              'Выгружать в облако',
              // Те же числа, что над полосой в разделе «Сохранения».
              '${_gb(src.cloud.$1)} из ${_gb(src.cloud.$2)} ГБ занято',
            ),
            _choice(
              s,
              'saveEvery',
              'Как часто',
              'Между точками игра не трогается',
              const ['1 мин', '5 мин', '15 мин'],
            ),
            _chip(
              'Шифрование на устройстве',
              'Ключ не покидает этот компьютер',
              'AES-256',
              hot: true,
            ),
            _choice(
              s,
              'keepPoints',
              'Сколько точек хранить',
              'Старые уходят в корзину на 30 дней',
              const ['10', '50', 'Все'],
            ),
          ],
        ),
      ],
    ),
    EvSettingSection(
      id: 'start',
      title: 'Запуск',
      icon: EvIcons.power,
      panels: [
        EvSettingPanel(
          label: 'Поведение окна',
          rows: [
            _flag(
              s,
              'autostart',
              'Запускать вместе с системой',
              'Свёрнутым, чтобы докачки не ждали вас',
            ),
            _choice(
              s,
              'onClose',
              'При закрытии окна',
              'Движок раздач продолжит работать в трее',
              const ['Свернуть в трей', 'Выйти'],
            ),
            EvSettingRow(
              title: 'Горячая клавиша оверлея',
              detail: 'Работает поверх запущенной игры',
              words: const ['Shift', 'Tab'],
              control: (_) => const EvKeyCaps(['Shift', 'Tab']),
            ),
            _flag(
              s,
              'awake',
              'Не гасить экран в игре',
              'Пока процесс игры жив',
            ),
          ],
        ),
      ],
    ),
    EvSettingSection(
      id: 'keys',
      title: 'Клавиши',
      icon: EvIcons.go,
      panels: [
        EvSettingPanel(
          label: 'Те же, что в строке подсказок внизу окна',
          rows: [
            for (final k in evKeyBindings)
              EvSettingRow(
                title: k.name,
                detail: k.detail,
                words: k.keys,
                control: (_) => EvKeyCaps(k.keys),
              ),
          ],
        ),
      ],
    ),
    EvSettingSection(
      id: 'about',
      title: 'О программе',
      icon: EvIcons.info,
      panels: [
        EvSettingPanel(
          label: 'Версии',
          rows: [
            _chip(
              'Evaporate',
              'Собрано 14 сентября 2026',
              EvSettings.version,
              hot: true,
            ),
            _chip(
              'Движок раздач',
              'DHT, PEX, шифрование протокола',
              EvSettings.engineVersion,
            ),
            _choice(
              s,
              'updates',
              'Обновления',
              'Ставятся ночью, когда вы не играете',
              const ['Автоматически', 'Спрашивать'],
            ),
            EvSettingRow(
              title: 'Лицензии зависимостей',
              detail: 'Всё открытое, из чего собрано приложение',
              control: (context) => EvMiniButton(
                label: 'Открыть',
                icon: EvIcons.info,
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'Evaporate',
                  applicationVersion: EvSettings.version,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  ];
}

EvSettingSection _effects(EvEffects fx) => EvSettingSection(
  id: 'fx',
  title: 'Эффекты',
  icon: EvIcons.boost,
  onReset: fx.reset,
  panels: [
    EvSettingPanel(
      label: 'Атмосфера',
      rows: [
        _switch(
          'Живой фон (шейдер)',
          'Объёмный плюм пара за интерфейсом',
          () => fx.livingBackground,
          (v) => fx.livingBackground = v,
        ),
        _switch(
          'Искры и частицы',
          'Восходящие угли, аддитивное смешивание',
          () => fx.sparks,
          (v) => fx.sparks = v,
        ),
        _switch(
          'Параллакс обложек',
          'Четыре слоя глубины, реакция на курсор',
          () => fx.parallax,
          (v) => fx.parallax = v,
        ),
        _switch(
          'Плёночное зерно',
          '5 % перекрытия, убирает бандинг на градиентах',
          () => fx.grain,
          (v) => fx.grain = v,
        ),
        _switch(
          'Стекло',
          'Рейл, полосы и панели размывают фон под собой',
          () => fx.glass,
          (v) => fx.glass = v,
        ),
        _switch(
          'Преломление стекла',
          EvGlassLens.supported
              ? 'Кадр под кромкой гнётся, как под толстым стеклом'
              : 'Кадр гнётся у кромки · нужен Impeller, в этой сборке '
                    'недоступно',
          () => fx.refraction && EvGlassLens.supported,
          EvGlassLens.supported ? (v) => fx.refraction = v : (_) {},
        ),
      ],
    ),
    EvSettingPanel(
      label: 'Качество и запуск',
      rows: [
        _segments<EvEffectsQuality>(
          'Уровень эффектов',
          'Плотность частиц и разрешение шейдера',
          {for (final q in EvEffectsQuality.values) q: q.label},
          () => fx.quality,
          (q) => fx.quality = q,
        ),
        _switch(
          'Ритуал запуска',
          'Испарение интерфейса и ударная волна при старте',
          () => fx.ritual,
          (v) => fx.ritual = v,
        ),
        _switch(
          'Удержание кнопки «Играть»',
          'Защита от случайного запуска · 620 мс',
          () => fx.holdToPlay,
          (v) => fx.holdToPlay = v,
        ),
        _switch(
          'Ограничить до 30 к/с в фоне',
          'Экономит батарею, когда окно неактивно',
          () => fx.throttleInBackground,
          (v) => fx.throttleInBackground = v,
        ),
      ],
    ),
  ],
);

/// Гигабайты облака: «4,1», «20».
String _gb(double v) => v == v.roundToDouble()
    ? '${v.round()}'
    : v.toStringAsFixed(1).replaceAll('.', ',');
