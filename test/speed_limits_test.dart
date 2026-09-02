import 'package:evaporate/models/app_settings.dart';
import 'package:evaporate/models/speed_limits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('перевод в байты', () {
    test('килобайты умножаются на 1024', () {
      const limits = SpeedLimits(download: 500, upload: 100);

      expect(limits.downloadBytes(playing: false), 500 * 1024);
      expect(limits.uploadBytes, 100 * 1024);
    });

    // Ноль — не «стоять», а «не ограничивать»: движок различает их по null.
    test('ноль означает отсутствие ограничения', () {
      const limits = SpeedLimits();

      expect(limits.downloadBytes(playing: false), isNull);
      expect(limits.uploadBytes, isNull);
      expect(limits.isUnlimited, isTrue);
    });

    test('отрицательное значение читается как отсутствие ограничения', () {
      final limits = SpeedLimits.fromJson({'download': -100, 'upload': -1});

      expect(limits.download, 0);
      expect(limits.upload, 0);
    });
  });

  group('предел на время игры', () {
    test('пока не играют, действует обычный предел', () {
      const limits = SpeedLimits(download: 800, whilePlaying: 200);

      expect(limits.downloadBytes(playing: false), 800 * 1024);
    });

    test('во время игры действует игровой предел', () {
      const limits = SpeedLimits(download: 800, whilePlaying: 200);

      expect(limits.downloadBytes(playing: true), 200 * 1024);
    });

    // Иначе настройка «на время игры» могла бы разогнать загрузку выше
    // обычного предела — то есть сделать ровно обратное задуманному.
    test('игровой предел не поднимает скорость выше обычной', () {
      const limits = SpeedLimits(download: 100, whilePlaying: 900);

      expect(limits.downloadBytes(playing: true), 100 * 1024);
    });

    test('игровой предел работает и без обычного', () {
      const limits = SpeedLimits(whilePlaying: 300);

      expect(limits.downloadBytes(playing: false), isNull);
      expect(limits.downloadBytes(playing: true), 300 * 1024);
    });

    test('без игрового предела игра ничего не меняет', () {
      const limits = SpeedLimits(download: 700);

      expect(
        limits.downloadBytes(playing: true),
        limits.downloadBytes(playing: false),
      );
    });

    // Раздачу игра не трогает: она идёт фоном и на отклик почти не влияет,
    // а перекрывать её вовсе — нечестно по отношению к раздающим.
    test('раздача от игры не зависит', () {
      const limits = SpeedLimits(upload: 50, whilePlaying: 100);

      expect(limits.uploadBytes, 50 * 1024);
    });
  });

  group('хранение', () {
    test('значения переживают запись и чтение', () {
      const limits = SpeedLimits(download: 1500, upload: 250, whilePlaying: 80);

      expect(SpeedLimits.fromJson(limits.toJson()), limits);
    });

    test('настройки несут ограничения с собой', () {
      final settings = const AppSettings(installDir: '/games')
          .copyWith(limits: const SpeedLimits(download: 400, whilePlaying: 50));

      final restored = AppSettings.fromJson(settings.toJson(), '/games');

      expect(restored.limits.download, 400);
      expect(restored.limits.whilePlaying, 50);
    });

    test('старый файл настроек без ограничений читается', () {
      final restored = AppSettings.fromJson({'installDir': '/games'}, '/games');

      expect(restored.limits, SpeedLimits.unlimited);
    });

    test('мусор вместо чисел не роняет чтение', () {
      final limits = SpeedLimits.fromJson({
        'download': 'быстро',
        'upload': null,
      });

      expect(limits.download, 0);
      expect(limits.upload, 0);
    });
  });
}
