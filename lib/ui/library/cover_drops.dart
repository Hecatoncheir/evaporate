import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets/decorative_motion.dart';

/// Капли, стекающие по обложке выбранной игры.
///
/// Шейдеру нужна не только форма капель, но и то, что под ними: он искажает
/// картинку, а не рисует поверх неё. Поэтому обложка декодируется в
/// текстуру, а не берётся снимком с экрана — снимать поддерево каждый кадр
/// вышло бы дороже самой отрисовки, да и тянуло бы за собой ещё одну
/// зависимость.
///
/// Отсюда и граница возможностей: у игры без обложки капли не идут — искажать
/// нечего. Показывать их на подложке с одним названием смысла нет.
class CoverDrops extends StatefulWidget {
  const CoverDrops({
    super.key,
    required this.enabled,
    required this.coverPath,
    required this.child,
  });

  final bool enabled;

  /// Путь к обложке или `null`, если её нет.
  final String? coverPath;

  /// Что показывать, пока текстура и шейдер не готовы, — и вместо них, если
  /// готовы они не будут.
  final Widget child;

  /// Программа одна на всё приложение: компиляция стоит дорого, а шейдер
  /// у всех плиток один и тот же.
  static Future<ui.FragmentProgram>? _program;

  static Future<ui.FragmentProgram> program() =>
      _program ??= ui.FragmentProgram.fromAsset('assets/shaders/drops.frag');

  /// Подменяется в тестах: настоящий шейдер там не собрать — он компилируется
  /// при сборке приложения, а прогон тестов её не делает.
  @visibleForTesting
  static void useProgram(Future<ui.FragmentProgram>? value) => _program = value;

  @override
  State<CoverDrops> createState() => _CoverDropsState();
}

class _CoverDropsState extends State<CoverDrops> {
  ui.FragmentShader? _shader;
  ui.Image? _cover;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CoverDrops old) {
    super.didUpdateWidget(old);
    if (old.coverPath != widget.coverPath || old.enabled != widget.enabled) {
      _load();
    }
  }

  /// Готовит шейдер и текстуру. Оба шага сетевые по духу — долгие и
  /// прерываемые, — поэтому у загрузки есть поколение: выключенный на
  /// полпути эффект не должен оживать после.
  Future<void> _load() async {
    final generation = ++_generation;
    final path = widget.coverPath;
    if (!widget.enabled || path == null) {
      _dropCover();
      return;
    }

    try {
      final program = await CoverDrops.program();
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted || generation != _generation) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _cover?.dispose();
        _cover = frame.image;
        _shader = program.fragmentShader();
      });
    } on Object {
      // Обложка могла исчезнуть, шейдер — не собраться на этой машине.
      // Плитка от этого не должна пропадать: показываем её как обычно.
      if (mounted && generation == _generation) _dropCover();
    }
  }

  void _dropCover() {
    if (_cover == null && _shader == null) return;
    setState(() {
      _cover?.dispose();
      _cover = null;
      _shader = null;
    });
  }

  @override
  void dispose() {
    _cover?.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    final cover = _cover;
    if (!widget.enabled || shader == null || cover == null) return widget.child;

    return DecorativeMotion(
      enabled: true,
      builder: (context, clock, _) => CustomPaint(
        key: const ValueKey('cover-drops'),
        painter: _DropsPainter(clock: clock, shader: shader, cover: cover),
        // Обложку рисует шейдер, но плитке нужен её размер: без ребёнка она
        // схлопнулась бы в точку.
        child: Opacity(opacity: 0, child: widget.child),
      ),
    );
  }
}

class _DropsPainter extends CustomPainter {
  _DropsPainter({
    required this.clock,
    required this.shader,
    required this.cover,
  }) : super(repaint: clock);

  final ValueListenable<double> clock;
  final ui.FragmentShader shader;
  final ui.Image cover;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // Порядок значений — порядок объявления в шейдере: время, размер,
    // потом текстура отдельным вызовом.
    shader
      ..setFloat(0, clock.value)
      ..setFloat(1, size.width)
      ..setFloat(2, size.height)
      ..setFloat(3, 1)
      ..setImageSampler(0, cover);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_DropsPainter old) =>
      old.shader != shader || old.cover != cover || old.clock != clock;
}
