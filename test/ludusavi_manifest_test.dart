import 'package:evaporate/services/saves/ludusavi_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('перевод путей базы в шаблоны', () {
    test('домашняя папка становится нашим плейсхолдером', () {
      expect(
        LudusaviManifest.toTemplate('<home>/Saves/slot1'),
        '{HOME}/Saves/slot1',
      );
    });

    test('windows-плейсхолдеры переводятся', () {
      expect(
        LudusaviManifest.toTemplate(r'<winAppData>\Studio\Game'),
        '{APPDATA}/Studio/Game',
      );
      expect(
        LudusaviManifest.toTemplate('<winDocuments>/My Games/Game'),
        '{DOCUMENTS}/My Games/Game',
      );
    });

    test('linux-плейсхолдеры переводятся', () {
      expect(
        LudusaviManifest.toTemplate('<xdgData>/game/saves'),
        '{APPSUPPORT}/game/saves',
      );
    });

    // Папку игры мы знаем сами — она становится нашим плейсхолдером.
    test('<base> становится папкой игры', () {
      expect(LudusaviManifest.toTemplate('<base>/saves'), '{GAME}/saves');
    });

    // Такие пути зависят от учётной записи в магазине или корня магазина:
    // подставить их вслепую нельзя.
    test('неизвестные плейсхолдеры отбрасываются', () {
      expect(LudusaviManifest.toTemplate('<root>/userdata'), isNull);
      expect(LudusaviManifest.toTemplate('<home>/<storeUserId>/saves'), isNull);
    });

    // Маску раскрывает файловая система, а не разбор базы: на какой машине
    // какие профили заведены, здесь знать неоткуда.
    test('маска доживает до шаблона', () {
      expect(LudusaviManifest.toTemplate('<home>/*/saves'), '{HOME}/*/saves');
    });

    // А вот «на любую глубину» мы не берём: обход всего дерева ради
    // сомнительной догадки дороже пользы.
    test('маска на любую глубину отбрасывается', () {
      expect(LudusaviManifest.toTemplate('<home>/**/saves'), isNull);
    });

    test('путь без единого плейсхолдера отбрасывается', () {
      expect(LudusaviManifest.toTemplate('C:/Games/Save'), isNull);
    });

    test('обратные слэши и дубли разделителей выправляются', () {
      expect(
        LudusaviManifest.toTemplate(r'<home>\\Games//Save'),
        '{HOME}/Games/Save',
      );
    });
  });

  group('разбор манифеста', () {
    // Синтетический манифест: структура настоящая, содержимое выдуманное.
    const sample = '''
Пример Игры:
  files:
    <home>/Saves/example:
      tags:
        - save
    <home>/Config/example:
      tags:
        - config
  steam:
    id: 12345
Только Windows:
  files:
    <winAppData>/OnlyWin:
      tags:
        - save
      when:
        - os: windows
Везде:
  files:
    <home>/Anywhere:
      tags:
        - save
      when: []
Непереносимая:
  files:
    <root>/userdata/<storeUserId>/saves:
      tags:
        - save
''';

    test('берутся только пути с сохранениями', () {
      final manifest = LudusaviManifest.parse(sample, platform: 'macos');
      final entry = manifest.entries.firstWhere(
        (e) => e.title == 'Пример Игры',
      );

      expect(entry.templates, ['{HOME}/Saves/example']);
      expect(entry.steamId, 12345);
    });

    test('чужая платформа отсекается', () {
      final onMac = LudusaviManifest.parse(sample, platform: 'macos');
      final onWindows = LudusaviManifest.parse(sample, platform: 'windows');

      final macEntry = onMac.entries
          .where((e) => e.title == 'Только Windows')
          .firstOrNull;
      final winEntry = onWindows.entries.firstWhere(
        (e) => e.title == 'Только Windows',
      );

      expect(macEntry?.templates ?? const [], isEmpty);
      expect(winEntry.templates, ['{APPDATA}/OnlyWin']);
    });

    test('пустое условие означает «на всех системах»', () {
      final manifest = LudusaviManifest.parse(sample, platform: 'linux');
      final entry = manifest.entries.firstWhere((e) => e.title == 'Везде');

      expect(entry.templates, ['{HOME}/Anywhere']);
    });

    test('запись без пригодных путей и без steam-id пропускается', () {
      final manifest = LudusaviManifest.parse(sample, platform: 'macos');

      expect(
        manifest.entries.where((e) => e.title == 'Непереносимая'),
        isEmpty,
      );
    });

    test('мусор вместо манифеста не роняет разбор', () {
      expect(LudusaviManifest.parse('просто строка').entries, isEmpty);
      expect(LudusaviManifest.parse('- список\n- элементов').entries, isEmpty);
    });

    test('индекс переживает сохранение и чтение', () {
      final manifest = LudusaviManifest.parse(sample, platform: 'macos');
      final restored = LudusaviManifest.fromJson(manifest.toJson());

      expect(restored.entries.length, manifest.entries.length);
      expect(restored.entries.first, manifest.entries.first);
    });
  });

  group('ветки реестра', () {
    const sample = '''
Пример Игры:
  files:
    <home>/Saves:
      tags:
        - save
  registry:
    HKEY_CURRENT_USER/Software/Studio/Game:
      tags:
        - save
    HKEY_CURRENT_USER/Software/Studio/Settings:
      tags:
        - config
''';

    // Реестр мы не переносим, но и умолчать о нём нельзя: снимок вышел бы
    // неполным, а человек решил бы, что забрал сейв целиком.
    test('берутся только ветки с сохранениями', () {
      final manifest = LudusaviManifest.parse(sample, platform: 'windows');
      final entry = manifest.entries.single;

      expect(entry.registryKeys, ['HKEY_CURRENT_USER/Software/Studio/Game']);
    });

    test('на других системах реестра нет', () {
      final manifest = LudusaviManifest.parse(sample, platform: 'macos');

      expect(manifest.entries.single.registryKeys, isEmpty);
    });

    test('ветки переживают сохранение и чтение', () {
      final manifest = LudusaviManifest.parse(sample, platform: 'windows');
      final restored = LudusaviManifest.fromJson(manifest.toJson());

      expect(restored.entries.single.registryKeys, hasLength(1));
    });
  });
}
