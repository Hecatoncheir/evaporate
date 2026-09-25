import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Иконка из дизайн-выгрузки.
///
/// Приборный стиль: только окружности, дуги и прямые, обводка 1.5 px на сетке
/// 24, скруглённые концы. Единственная сплошная — `play`, потому что это
/// единственное необратимое действие.
///
/// Файлы лежат в `design/assets/icons` и пересобираются `build_assets.py`,
/// так что макеты и приложение не могут разойтись.
class EvIcon extends StatelessWidget {
  const EvIcon(this.name, {super.key, this.size = 18, this.color});

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? DefaultTextStyle.of(context).style.color;
    return SvgPicture.asset(
      'design/assets/icons/$name.svg',
      width: size,
      height: size,
      colorFilter: c == null ? null : ColorFilter.mode(c, BlendMode.srcIn),
    );
  }
}

/// Знак приложения. Скругление плитки диктует операционная система,
/// а не наша шкала радиусов, поэтому знак берётся как есть.
class EvMark extends StatelessWidget {
  const EvMark({super.key, this.size = 36, this.variant = 'appicon-a-vent'});

  final double size;
  final String variant;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'design/assets/logo/$variant.svg',
    width: size,
    height: size,
  );
}

/// Имена иконок, чтобы не ошибаться в строках.
abstract final class EvIcons {
  static const library = 'library';
  static const download = 'download';
  static const saves = 'saves';
  static const settings = 'settings';
  static const friends = 'friends';
  static const search = 'search';
  static const play = 'play';
  static const pause = 'pause';
  static const close = 'close';
  static const go = 'go';
  static const info = 'info';
  static const peers = 'peers';
  static const seed = 'seed';
  static const speed = 'speed';
  static const disk = 'disk';
  static const cloud = 'cloud';
  static const folder = 'folder';
  static const trophy = 'trophy';
  static const verified = 'verified';
  static const boost = 'boost';
  static const audio = 'audio';
  static const desktop = 'desktop';
  static const laptop = 'laptop';

  /// Внимание: ждём внешнего — жёлтая строка под кнопкой.
  static const alert = 'alert';

  /// Диск: куда встанет установка и сколько там места.
  static const drive = 'drive';

  /// Завершить игру.
  static const power = 'power';

  /// Сети нет.
  static const wifiOff = 'wifi-off';

  /// Галочка: выбрать эту версию сохранения.
  static const check = 'check';

  /// Написать другу.
  static const note = 'note';

  /// Две ветки сохранения разошлись.
  static const merge = 'merge';

  /// Magnet-ссылка вместо файла раздачи.
  static const magnet = 'magnet';

  /// Повторить: перекачать части, проверить связь.
  static const retry = 'retry';

  /// Скопировать: код для друзей — в буфер обмена.
  static const copy = 'copy';

  /// Скрыто: друг выключил это в своём профиле.
  static const lock = 'lock';

  /// Скриншот из оверлея.
  static const camera = 'camera';

  /// Записать последние 30 секунд.
  static const rec = 'rec';

  /// Вид «Стена» — сетка обложек.
  static const wall = 'wall';

  /// Вид «Терминал» — таблица.
  static const rows = 'rows';

  /// Режим «Пульт» для геймпада.
  static const pad = 'pad';
}
