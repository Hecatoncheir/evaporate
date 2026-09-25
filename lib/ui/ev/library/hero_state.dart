import '../returning/return_data.dart';
import '../widgets/ev_icon.dart';

/// Состояние игры в герое. Оно меняет не только кнопку: надглавие,
/// описание, чипы и строку под кнопкой — всё, что герой говорит об игре.
///
/// Прототип держит те же шесть состояний в `HERO`, а карточка игры
/// читает их через `cardState`, поэтому полоса действий в ней говорит то
/// же самое, что герой.
enum EvHeroState {
  /// Установлена, можно играть.
  ready,

  /// В библиотеке, но на диске её нет.
  notInstalled,

  /// Установлена, но есть обновление.
  update,

  /// Идёт установка: на месте кнопки — прогресс.
  installing,

  /// Игра запущена: кнопка стала статусом.
  running,

  /// Нет сети. Локальное работает, сетевое гаснет.
  offline,

  /// Второй запуск: вы вернулись. Герой помнит место, где закрыли игру,
  /// а рядом — что изменилось, пока вас не было.
  returned,
}

/// Цвет строки под кнопкой кодирует причину, а не громкость.
enum EvNoteTone { plain, warn, bad, cool }

/// Строка под кнопкой: куда встанет установка, чего не будет в офлайне.
class EvHeroNote {
  const EvHeroNote(
    this.text, {
    this.icon = EvIcons.info,
    this.tone = EvNoteTone.plain,
  });

  final String text;
  final String icon;
  final EvNoteTone tone;
}

/// Прогресс установки на месте кнопки «Играть».
class EvInstallProgress {
  const EvInstallProgress({
    required this.label,
    required this.value,
    required this.detail,
  });

  /// «Распаковка и проверка».
  final String label;

  /// 0…1.
  final double value;

  /// «28.0 ГБ из 68.4 ГБ · 84 МБ/с на диск · осталось 12 мин».
  final String detail;
}

/// Что герой показывает в этом состоянии.
class EvHeroContent {
  const EvHeroContent({
    required this.eyebrow,
    required this.blurb,
    required this.chips,
    this.note,
    this.action,
    this.actionCaption,
    this.second,
    this.secondIcon,
    this.install,
    this.runningFor,
    this.savePoint,
  });

  final String eyebrow;
  final String blurb;

  /// Чипы под описанием; первый — состояние, он горячий.
  final List<(String, bool)> chips;

  final EvHeroNote? note;

  /// Подпись главной кнопки вместо «Играть»: «Установить», «Обновить
  /// и играть». `null` — кнопка запуска с удержанием.
  final String? action;

  /// Приписка на главной кнопке: размер загрузки, время патча.
  final String? actionCaption;

  /// Вторая кнопка рядом: «Указать папку вручную», «Играть без
  /// обновления». `null` — «Подробнее».
  final String? second;

  final String? secondIcon;

  /// Прогресс вместо кнопок.
  final EvInstallProgress? install;

  /// Сколько идёт игра: «01:04:12».
  final String? runningFor;

  /// Точка сохранения под кнопкой — во втором запуске.
  final EvSaveSpot? savePoint;
}
