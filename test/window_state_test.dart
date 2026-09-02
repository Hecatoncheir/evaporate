import 'dart:io';
import 'dart:ui';

import 'package:evaporate/core/json_store.dart';
import 'package:evaporate/models/window_start_mode.dart';
import 'package:evaporate/services/system/window_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Поддельное окно: настоящее в тестовой среде не создать.
class FakeWindow implements WindowController {
  FakeWindow({Rect? bounds, this.maximized = false})
    : bounds = bounds ?? const Rect.fromLTWH(0, 0, 1280, 720);

  Rect bounds;
  bool maximized;
  bool shown = false;
  final calls = <String>[];

  @override
  Future<Rect> getBounds() async => bounds;

  @override
  Future<void> setBounds(Rect value) async {
    calls.add('setBounds');
    bounds = value;
  }

  @override
  Future<bool> isMaximized() async => maximized;

  @override
  Future<void> maximize() async {
    calls.add('maximize');
    maximized = true;
  }

  @override
  Future<void> unmaximize() async {
    calls.add('unmaximize');
    maximized = false;
  }

  @override
  Future<void> show() async {
    calls.add('show');
    shown = true;
  }
}

void main() {
  late Directory tmp;
  late JsonStore store;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('evaporate_window_');
    store = JsonStore(p.join(tmp.path, 'window.json'));
  });

  tearDown(() async {
    try {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    } on FileSystemException {
      // Остатки временной папки на результат теста не влияют.
    }
  });

  WindowState stateWith(FakeWindow window) =>
      WindowState(store: store, controller: window);

  group('приведение к разумному', () {
    test('слишком маленькое окно расширяется до минимума', () {
      const tiny = WindowGeometry(x: 10, y: 10, width: 120, height: 80);

      final fixed = tiny.sanitized();

      expect(fixed.width, WindowGeometry.minWidth);
      expect(fixed.height, WindowGeometry.minHeight);
    });

    // Монитор могли отключить: окно по старым числам окажется за краем
    // экрана, и пользователь решит, что приложение не запустилось.
    test('положение с исчезнувшего монитора отбрасывается', () {
      const offscreen = WindowGeometry(
        x: 4800,
        y: -3000,
        width: 1280,
        height: 720,
      );

      final fixed = offscreen.sanitized();

      expect(fixed.x, WindowGeometry.fallback.x);
      expect(fixed.y, WindowGeometry.fallback.y);
    });

    test('небольшой заход за край сохраняется', () {
      const nudged = WindowGeometry(x: -40, y: -20, width: 1280, height: 720);

      final fixed = nudged.sanitized();

      expect(fixed.x, -40, reason: 'так окна и раскладывают, это норма');
      expect(fixed.y, -20);
    });

    test('мусор вместо чисел не переживает проверку', () {
      const broken = WindowGeometry(
        x: double.nan,
        y: 0,
        width: double.nan,
        height: 720,
      );

      final fixed = broken.sanitized();

      expect(fixed.x, WindowGeometry.fallback.x);
      expect(fixed.width, WindowGeometry.fallback.width);
    });

    test('запись переживает сохранение и чтение', () {
      const geometry = WindowGeometry(
        x: 100,
        y: 200,
        width: 1400,
        height: 900,
        maximized: true,
      );

      expect(WindowGeometry.fromJson(geometry.toJson()), geometry);
    });
  });

  group('восстановление', () {
    test('запомненные размер и положение возвращаются', () async {
      await store.write(
        const WindowGeometry(x: 120, y: 60, width: 1400, height: 900).toJson(),
      );
      final window = FakeWindow();

      await stateWith(window).restore(WindowStartMode.remembered);

      expect(window.bounds, const Rect.fromLTWH(120, 60, 1400, 900));
      expect(window.shown, isTrue);
    });

    // Ради этого режима и нужен значок в трее: окна пользователь не увидит.
    test('в режиме «в трей» окно не показывается', () async {
      await store.write(
        const WindowGeometry(x: 120, y: 60, width: 1400, height: 900).toJson(),
      );
      final window = FakeWindow();

      await stateWith(window).restore(WindowStartMode.minimized);

      expect(window.shown, isFalse);
      expect(
        window.bounds,
        const Rect.fromLTWH(120, 60, 1400, 900),
        reason: 'развёрнутое из трея окно должно оказаться там же, где было',
      );
    });

    test('развёрнутое окно возвращается развёрнутым', () async {
      await store.write(
        const WindowGeometry(
          x: 10,
          y: 10,
          width: 1280,
          height: 720,
          maximized: true,
        ).toJson(),
      );
      final window = FakeWindow();

      await stateWith(window).restore(WindowStartMode.remembered);

      expect(window.maximized, isTrue);
      // Размер развёрнутому окну не задаём: он всё равно будет по экрану.
      expect(window.calls, isNot(contains('setBounds')));
    });

    test('«всегда разворачивать» перекрывает запомненное', () async {
      await store.write(
        const WindowGeometry(x: 120, y: 60, width: 1400, height: 900).toJson(),
      );
      final window = FakeWindow();

      await stateWith(window).restore(WindowStartMode.maximized);

      expect(window.maximized, isTrue);
    });

    test('первый запуск обходится без записи', () async {
      final window = FakeWindow();

      await stateWith(window).restore(WindowStartMode.remembered);

      expect(window.calls, isNot(contains('setBounds')));
      expect(window.shown, isTrue);
    });

    // Иначе пользователь увидит, как окно прыгает из угла в угол.
    test('окно показывается последним', () async {
      await store.write(
        const WindowGeometry(x: 120, y: 60, width: 1400, height: 900).toJson(),
      );
      final window = FakeWindow();

      await stateWith(window).restore(WindowStartMode.remembered);

      expect(window.calls.last, 'show');
    });
  });

  group('запоминание', () {
    test('обычное окно запоминается целиком', () async {
      final window = FakeWindow(bounds: const Rect.fromLTWH(30, 40, 1500, 800));

      await stateWith(window).save();

      final saved = await stateWith(window).read();
      expect(saved!.x, 30);
      expect(saved.width, 1500);
      expect(saved.maximized, isFalse);
    });

    // У развёрнутого окна размер равен экрану: запомнив его, мы бы отдали
    // пользователю экран вместо прежнего окна при сворачивании.
    test('у развёрнутого окна прежний размер не затирается', () async {
      await store.write(
        const WindowGeometry(x: 90, y: 70, width: 1300, height: 800).toJson(),
      );
      final window = FakeWindow(
        bounds: const Rect.fromLTWH(0, 0, 3840, 2160),
        maximized: true,
      );

      await stateWith(window).save();

      final saved = await stateWith(window).read();
      expect(saved!.maximized, isTrue);
      expect(saved.width, 1300);
      expect(saved.x, 90);
    });
  });
}
