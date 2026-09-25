import 'package:flutter/widgets.dart';

/// Строка настройки: подпись, пояснение и один контрол справа.
@immutable
class EvSettingRow {
  const EvSettingRow({
    required this.title,
    required this.detail,
    required this.control,
    this.words = const [],
    this.leading,
    this.dim = false,
  });

  final String title;
  final String detail;
  final WidgetBuilder control;

  /// Что ещё ищется в строке: подписи сегментов, клавиши, значение чипа.
  final List<String> words;

  final WidgetBuilder? leading;

  /// Строка ждёт другой настройки — звука, пока слой выключен.
  final bool dim;
}

/// Панель раздела: подпись, пояснение и строки. [body] — то, что не
/// строка: расписание, темы, папки. Оно показывается, когда видна панель.
@immutable
class EvSettingPanel {
  const EvSettingPanel({
    required this.label,
    this.note,
    this.body,
    this.rows = const [],
    this.glowCorner = false,
  });

  final String label;
  final String? note;
  final WidgetBuilder? body;
  final List<EvSettingRow> rows;
  final bool glowCorner;
}

/// Раздел, который можно назвать вслух: «Облик», «Загрузки».
@immutable
class EvSettingSection {
  const EvSettingSection({
    required this.id,
    required this.title,
    required this.icon,
    required this.panels,
    this.onReset,
  });

  final String id;
  final String title;
  final String icon;
  final List<EvSettingPanel> panels;

  /// «Сбросить» в заголовке. `null` — сбрасывать нечего.
  final VoidCallback? onReset;
}

/// Что видно при запросе: разделы, панели и строки. Запрос ищется
/// и в заголовках: «скорость» живёт в «Расписании скорости», а не
/// в подписи строки, поэтому раскрывает всю панель.
@immutable
class EvSettingsMatch {
  const EvSettingsMatch._(this.query, this._rows);

  factory EvSettingsMatch.of(List<EvSettingSection> sections, String query) {
    final q = stem(query.trim().toLowerCase());
    final rows = <EvSettingPanel, List<EvSettingRow>>{};
    for (final s in sections) {
      final whole = q.isEmpty || _has(s.title, q);
      for (final p in s.panels) {
        final all = whole || _has(p.label, q) || _has(p.note, q);
        final hit = [
          for (final r in p.rows)
            if (all || _row(r, q)) r,
        ];
        // Панель без строк видна, только если нашлась сама.
        if (all || hit.isNotEmpty) rows[p] = hit;
      }
    }
    return EvSettingsMatch._(q, rows);
  }

  /// Запрос в нижнем регистре, без пробелов по краям, без окончания.
  final String query;

  /// Основа слова: «скорость» ищет и «скорости», «облако» — «облака».
  /// Окончание срезается у слов длиннее четырёх букв — короткие («порт»)
  /// от этого стали бы слишком общими.
  static String stem(String q) {
    const endings = 'аеёиоуыьъэюяй';
    if (q.length <= 4 || q.contains(' ')) return q;
    return endings.contains(q[q.length - 1]) ? q.substring(0, q.length - 1) : q;
  }

  final Map<EvSettingPanel, List<EvSettingRow>> _rows;

  bool panel(EvSettingPanel p) => _rows.containsKey(p);

  bool section(EvSettingSection s) => s.panels.any(panel);

  /// Строки панели, которые видны.
  List<EvSettingRow> rows(EvSettingPanel p) => _rows[p] ?? const [];

  bool get empty => _rows.isEmpty;

  /// Где в подписи подсветить совпадение; `null` — подсвечивать нечего
  /// (запроса нет, строка видна потому, что нашёлся весь раздел, или
  /// совпало не в подписи).
  (int, int)? highlight(String title) {
    if (query.isEmpty) return null;
    final at = title.toLowerCase().indexOf(query);
    return at < 0 ? null : (at, at + query.length);
  }

  static bool _has(String? text, String q) =>
      text != null && text.toLowerCase().contains(q);

  static bool _row(EvSettingRow r, String q) =>
      _has(r.title, q) || _has(r.detail, q) || r.words.any((w) => _has(w, q));
}
