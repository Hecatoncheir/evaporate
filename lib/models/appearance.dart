import 'package:equatable/equatable.dart';

import 'app_theme_mode.dart';
import 'effect_quality.dart';
import 'library_effect.dart';

/// Облик приложения: схема, язык, масштабы и украшения.
///
/// Одним значением, а не полями настроек: правится это вместе, из одной
/// карточки, и читается вместе — сетка библиотеки смотрит на украшения и
/// масштаб, и больше ей от настроек не нужно ничего. Смена папки игр или
/// прокси облика не касается и библиотеку не перестраивает.
///
/// На диске запись плоская, ключи прежние: [toJson] кладёт свои поля в
/// общую карту настроек, [Appearance.fromJson] читает их оттуда же.
class Appearance extends Equatable {
  const Appearance({
    this.themeMode = AppThemeMode.system,
    this.locale,
    this.interfaceScale = 1,
    this.libraryScale = 1,
    this.libraryEffects = true,
    this.effects = LibraryEffect.shipped,
    this.effectQuality = EffectQuality.full,
    this.sound = true,
  });

  /// Светлая, тёмная или как в системе.
  final AppThemeMode themeMode;

  /// Код языка интерфейса или null — брать язык системы.
  ///
  /// Хранится строкой, а не Locale: в файле настроек это всё равно
  /// строка, и лишний тип только добавил бы преобразований.
  final String? locale;

  /// Масштаб интерфейса и размер обложек независимы друг от друга и
  /// переживают перезапуск.
  final double interfaceScale;
  final double libraryScale;
  static const minInterfaceScale = 0.85;
  static const maxInterfaceScale = 1.25;
  static const minLibraryScale = 0.75;
  static const maxLibraryScale = 1.5;

  /// Общий выключатель; индивидуальные предпочтения сохраняются под ним.
  final bool libraryEffects;

  /// Какие украшения включены.
  ///
  /// Набором, а не полем на каждое: чем они отличаются друг от друга,
  /// сказано один раз — в [LibraryEffect], — а здесь остаётся только
  /// выбор человека.
  final Set<LibraryEffect> effects;

  /// Насколько дороги включённые украшения — отдельно от того, какие
  /// включены.
  final EffectQuality effectQuality;

  /// Звучит ли интерфейс. Включён по умолчанию — так решил владелец
  /// (`docs/decisions/0013`), — но выключатель обязан быть: звук, который
  /// нечем погасить, кроме системной громкости, — это не «по умолчанию», а
  /// «всегда». Громкость и классы звуков придут с настройками прототипа.
  final bool sound;

  /// Языки, на которые приложение переведено.
  static const supportedLocales = ['ru', 'en'];

  /// Включено ли украшение само по себе.
  ///
  /// Общий выключатель здесь не участвует: смотреть на него — дело
  /// виджета, а рамка выбора ему и вовсе не подчиняется.
  bool isOn(LibraryEffect effect) => effects.contains(effect);

  /// Горит ли украшение с учётом общего выключателя.
  bool shows(LibraryEffect effect) => libraryEffects && isOn(effect);

  /// Тот же облик с переключённым украшением.
  Appearance withEffect(LibraryEffect effect, {required bool on}) => copyWith(
    effects: {
      for (final each in LibraryEffect.values)
        if (each == effect ? on : isOn(each)) each,
    },
  );

  Appearance copyWith({
    AppThemeMode? themeMode,
    Object? locale = _unset,
    double? interfaceScale,
    double? libraryScale,
    bool? libraryEffects,
    Set<LibraryEffect>? effects,
    EffectQuality? effectQuality,
    bool? sound,
  }) => Appearance(
    themeMode: themeMode ?? this.themeMode,
    locale: locale == _unset ? this.locale : locale as String?,
    interfaceScale: interfaceScale ?? this.interfaceScale,
    libraryScale: libraryScale ?? this.libraryScale,
    libraryEffects: libraryEffects ?? this.libraryEffects,
    effects: effects ?? this.effects,
    effectQuality: effectQuality ?? this.effectQuality,
    sound: sound ?? this.sound,
  );

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode.name,
    if (locale != null) 'locale': locale,
    'interfaceScale': interfaceScale,
    'libraryScale': libraryScale,
    'libraryEffects': libraryEffects,
    // Ключи прежние, по одному на украшение: профили, записанные до
    // появления набора, читаются как раньше — и записываются так же.
    for (final effect in LibraryEffect.values)
      effect.jsonKey: effects.contains(effect),
    'effectQuality': effectQuality.name,
    'sound': sound,
  };

  /// Прочитанные значения зажимаются в границы, а незнакомые становятся
  /// значениями по умолчанию: испорченный файл не должен давать окно, в
  /// котором ничего не найти, или запирать в чужой теме и чужом языке.
  factory Appearance.fromJson(Map<String, dynamic> json) => Appearance(
    themeMode: _themeModeFromName(json['themeMode'] as String?),
    locale: _localeFromJson(json['locale']),
    interfaceScale: _scale(
      json['interfaceScale'],
      minInterfaceScale,
      maxInterfaceScale,
    ),
    libraryScale: _scale(
      json['libraryScale'],
      minLibraryScale,
      maxLibraryScale,
    ),
    libraryEffects: json['libraryEffects'] as bool? ?? true,
    effects: _effectsFromJson(json),
    effectQuality: EffectQuality.fromName(json['effectQuality']),
    sound: json['sound'] as bool? ?? true,
  );

  @override
  List<Object?> get props => [
    themeMode,
    locale,
    interfaceScale,
    libraryScale,
    libraryEffects,
    effects,
    effectQuality,
    sound,
  ];

  static const _unset = Object();

  /// Незнакомый язык читается как «из системы»: приложение переведено
  /// не на все языки мира, и чужой файл настроек не должен оставлять
  /// пользователя перед пустым интерфейсом.
  static String? _localeFromJson(Object? value) {
    if (value is! String) return null;
    return supportedLocales.contains(value) ? value : null;
  }

  /// Неизвестное значение — это «как в системе»: чужой или испорченный
  /// файл настроек не должен запирать пользователя в чужой теме.
  static AppThemeMode _themeModeFromName(String? name) => switch (name) {
    'light' => AppThemeMode.light,
    'dark' => AppThemeMode.dark,
    _ => AppThemeMode.system,
  };

  /// Украшения из файла настроек.
  ///
  /// Ключи читаются по одному, как и писались: профиль, записанный до
  /// появления набора, приходит с прежними полями, а неназванное берёт
  /// значение по умолчанию — там могло не быть ещё и самого украшения.
  static Set<LibraryEffect> _effectsFromJson(Map<String, dynamic> json) => {
    for (final effect in LibraryEffect.values)
      if (json[effect.jsonKey] as bool? ??
          LibraryEffect.shipped.contains(effect))
        effect,
  };

  static double _scale(Object? value, double min, double max) =>
      value is num && value.isFinite ? value.toDouble().clamp(min, max) : 1;
}
