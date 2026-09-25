import 'package:flutter/services.dart';

/// Грузит настоящие шрифты приложения вместо служебного тестового.
///
/// Служебный набирает каждую букву квадратом в кегль, и строка выходит
/// вдвое шире настоящей. Там, где тест проверяет саму раскладку — влез ли
/// ряд обложек, встала ли панель в строку, — мерить надо тем, что увидит
/// человек. Звать из `setUpAll`: шрифт грузится в изолят файла тестов
/// один раз.
Future<void> loadAppFonts() async {
  for (final MapEntry(key: family, value: asset) in const {
    'Unbounded': 'assets/fonts/Unbounded.ttf',
    'Golos Text': 'assets/fonts/GolosText.ttf',
    'JetBrains Mono': 'assets/fonts/JetBrainsMono.ttf',
    'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
  }.entries) {
    await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
  }
}
