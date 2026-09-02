import 'dart:ui';

import 'package:equatable/equatable.dart';

import '../../core/json_store.dart';

/// Размер и положение окна между запусками.
class WindowGeometry extends Equatable {
  const WindowGeometry({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.maximized = false,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final bool maximized;

  /// Значение по умолчанию совпадает с тем, что задаёт нативная часть.
  static const fallback = WindowGeometry(
    x: 0,
    y: 0,
    width: 1280,
    height: 720,
    maximized: false,
  );

  static const minWidth = 900.0;
  static const minHeight = 620.0;

  /// Больше этого не бывает даже у стены мониторов: всё сверх — мусор.
  static const maxSide = 20000.0;

  Rect get bounds => Rect.fromLTWH(x, y, width, height);

  /// Приводит запомненные значения к разумным.
  ///
  /// Монитор могли отключить или сменить разрешение, и окно, восстановленное
  /// по старым числам, окажется за краем экрана — пользователь решит, что
  /// приложение не запустилось. Совсем неправдоподобное положение отбрасываем
  /// и возвращаемся к значению по умолчанию.
  WindowGeometry sanitized() {
    // NaN отсеиваем до clamp, а не после: он сравнивает через compareTo, где
    // NaN больше любого числа, и потому возвращает не NaN, а верхнюю границу.
    // Испорченная ширина превратилась бы в окно на двадцать тысяч точек.
    final left = x.isNaN ? fallback.x : x;
    final top = y.isNaN ? fallback.y : y;
    final w = (width.isNaN ? fallback.width : width).clamp(minWidth, maxSide);
    final h = (height.isNaN ? fallback.height : height).clamp(
      minHeight,
      maxSide,
    );

    // Небольшой заход за край нормален: так окна и раскладывают. А вот
    // тысячи пикселей мимо — это след исчезнувшего монитора.
    final offscreen =
        left < -w + 120 || top < -80 || left > maxSide || top > maxSide;

    return WindowGeometry(
      x: offscreen ? fallback.x : left,
      y: offscreen ? fallback.y : top,
      width: w,
      height: h,
      maximized: maximized,
    );
  }

  /// Разворачивалось ли окно, помнить стоит отдельно от размера: развёрнутое
  /// окно надо восстановить развёрнутым, но при сворачивании вернуть прежний
  /// размер, а не размер экрана.
  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'maximized': maximized,
  };

  factory WindowGeometry.fromJson(Map<String, dynamic> json) => WindowGeometry(
    x: (json['x'] as num?)?.toDouble() ?? fallback.x,
    y: (json['y'] as num?)?.toDouble() ?? fallback.y,
    width: (json['width'] as num?)?.toDouble() ?? fallback.width,
    height: (json['height'] as num?)?.toDouble() ?? fallback.height,
    maximized: json['maximized'] as bool? ?? false,
  );

  @override
  List<Object?> get props => [x, y, width, height, maximized];
}

/// Управление окном, отделённое от конкретной реализации.
///
/// Нужно ради тестов: настоящее окно в тестовой среде не создать, а логику
/// восстановления проверить надо.
abstract class WindowController {
  Future<Rect> getBounds();
  Future<void> setBounds(Rect bounds);
  Future<bool> isMaximized();
  Future<void> maximize();
  Future<void> unmaximize();
  Future<void> show();
}

/// Хранит геометрию окна и восстанавливает её при запуске.
class WindowState {
  WindowState({required this._store, required this._controller});

  final JsonStore _store;
  final WindowController _controller;

  Future<WindowGeometry?> read() async {
    final json = await _store.read();
    if (json == null) return null;
    return WindowGeometry.fromJson(json);
  }

  /// Ставит окно так, как договорились настройки.
  ///
  /// [remember] — восстанавливать прошлые размер и положение.
  /// [alwaysMaximized] — разворачивать всегда, что бы ни было запомнено.
  Future<void> restore({
    required bool remember,
    required bool alwaysMaximized,
  }) async {
    final saved = remember ? (await read())?.sanitized() : null;

    if (saved != null && !saved.maximized) {
      await _controller.setBounds(saved.bounds);
    }
    if (alwaysMaximized || (saved?.maximized ?? false)) {
      await _controller.maximize();
    }
    // Окно показываем последним: иначе пользователь увидит, как оно
    // прыгает из одного положения в другое.
    await _controller.show();
  }

  /// Запоминает текущее состояние окна.
  Future<void> save() async {
    final maximized = await _controller.isMaximized();
    final bounds = await _controller.getBounds();

    // У развёрнутого окна размер равен экрану — запоминать его бессмысленно:
    // при сворачивании пользователь ждёт прежний размер. Поэтому оставляем
    // прошлые числа, меняя только признак.
    if (maximized) {
      final previous = (await read()) ?? WindowGeometry.fallback;
      await _store.write(
        WindowGeometry(
          x: previous.x,
          y: previous.y,
          width: previous.width,
          height: previous.height,
          maximized: true,
        ).toJson(),
      );
      return;
    }

    await _store.write(
      WindowGeometry(
        x: bounds.left,
        y: bounds.top,
        width: bounds.width,
        height: bounds.height,
      ).toJson(),
    );
  }
}
