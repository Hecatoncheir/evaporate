// Спайк «как есть»: прототип evaporate_design, перенесённый без правок в
// lib/ui/ev, на настоящей библиотеке. Не для слияния — ради снимков экрана.
//
// Запуск: evaporate.exe <папка с копией library.json> <папка для PNG>

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'ui/library/effects/cover_drops.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:window_manager/window_manager.dart';

import 'ui/ev/data/real_library.dart';
import 'ui/ev/ev_app.dart';

const _client = Size(1440, 900);

final _boundary = GlobalKey();

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final dataDir = args.isNotEmpty ? args[0] : '.';
  final outDir = args.length > 1 ? args[1] : '.';
  // google_fonts кладёт скачанные шрифты в папку поддержки приложения, а
  // у этой сборки она — настоящая %APPDATA%/dev.evaporate/evaporate.
  // Трогать её спайку нельзя, поэтому все папки уводятся в outDir.
  PathProviderPlatform.instance = _ScratchPaths('$outDir/spike_home');
  _logPath = '$outDir/asis.log';
  // Сторож: что бы ни случилось, процесс не остаётся висеть.
  Timer(const Duration(seconds: 90), () => exit(3));

  evRealLibrary = EvRealLibrary.load(dataDir);
  _log(
    'games=${evRealLibrary!.games.length} '
    'hero=${evRealLibrary!.hero.title} '
    'sessions=${evRealLibrary!.sessions.length} '
    'covers=${evRealLibrary!.coversFound}',
  );

  await windowManager.ensureInitialized();
  await windowManager.setSize(_client);
  runApp(RepaintBoundary(key: _boundary, child: const EvaporateApp()));
  unawaited(_script(outDir));
}

Future<void> _script(String outDir) async {
  await Future<void>.delayed(const Duration(seconds: 1));
  await _fitClient();
  await Future<void>.delayed(const Duration(seconds: 7));
  await _capture('$outDir/asis-library.png');

  // Второй кадр: наведение на вторую обложку полки и прокрутка вниз.
  final binding = GestureBinding.instance;
  binding.handlePointerEvent(
    const PointerScrollEvent(
      kind: ui.PointerDeviceKind.mouse,
      position: Offset(720, 500),
      scrollDelta: Offset(0, 420),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 1200));
  _hoverSecondCard(binding);
  await Future<void>.delayed(const Duration(seconds: 2));
  await _capture('$outDir/asis-library-2.png');
  _probeDrops();
  await _captureCard('$outDir/card-1.png');
  await Future<void>.delayed(const Duration(seconds: 3));
  await _captureCard('$outDir/card-2.png');
  exit(0);
}

/// Сколько обложек с каплями сейчас в дереве и рисуют ли они шейдером.
void _probeDrops() {
  var enabled = 0;
  var painting = 0;
  void visit(Element e) {
    final w = e.widget;
    if (w is CoverDrops && w.enabled) enabled++;
    if (w.key == const ValueKey('cover-drops')) painting++;
    e.visitChildElements(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildElements(visit);
  _log('drops enabled=$enabled painting=$painting');
}

/// Крупный снимок обложки, на которой идут капли.
Future<void> _captureCard(String path) async {
  Element? target;
  void visit(Element e) {
    if (e.widget.key == const ValueKey('cover-drops')) target ??= e;
    e.visitChildElements(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildElements(visit);
  final found = target;
  if (found == null) {
    _log('no drops to capture');
    return;
  }
  RenderObject? o = found.findRenderObject();
  while (o != null && o is! RenderRepaintBoundary) {
    o = o.parent;
  }
  if (o is! RenderRepaintBoundary) return;
  final image = await o.toImage(pixelRatio: 3);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  _log('saved $path ${image.width}x${image.height}');
}

/// Клиентская область ровно 1440×900: рамку окна система считает по-своему,
/// поэтому размер правится по разнице с тем, что увидел Flutter.
Future<void> _fitClient() async {
  for (var i = 0; i < 3; i++) {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final logical = view.physicalSize / view.devicePixelRatio;
    final dw = _client.width - logical.width;
    final dh = _client.height - logical.height;
    _log('client=$logical dpr=${view.devicePixelRatio}');
    if (dw.abs() < .5 && dh.abs() < .5) return;
    final outer = await windowManager.getSize();
    await windowManager.setSize(Size(outer.width + dw, outer.height + dh));
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }
}

/// Наводит мышь на вторую обложку полки «Библиотека»: ищет в дереве
/// отрисовки вторую по счёту карточку ширины полки.
void _hoverSecondCard(GestureBinding binding) {
  final root = _boundary.currentContext?.findRenderObject();
  if (root == null) return;
  final hits = <Rect>[];
  void visit(RenderObject o) {
    if (o is RenderMouseRegion && o.hasSize) {
      final box = o.localToGlobal(Offset.zero) & o.size;
      if (box.width > 120 && box.width < 260 && box.height > 150) {
        hits.add(box);
      }
    }
    o.visitChildren(visit);
  }

  visit(root);
  hits.sort((a, b) {
    final dy = a.top.compareTo(b.top);
    return dy != 0 ? dy : a.left.compareTo(b.left);
  });
  _log('mouse regions=${hits.length}');
  // Поиск по дереву находит и чужие области мыши (их больше сотни), поэтому
  // точка задана по первому снимку: центр второй обложки после прокрутки.
  const target = Offset(389, 474);
  binding.handlePointerEvent(
    PointerAddedEvent(kind: ui.PointerDeviceKind.mouse, position: target),
  );
  binding.handlePointerEvent(
    PointerHoverEvent(kind: ui.PointerDeviceKind.mouse, position: target),
  );
}

Future<void> _capture(String path) async {
  final boundary =
      _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  _log('saved $path ${image.width}x${image.height}');
}

class _ScratchPaths extends PathProviderPlatform {
  _ScratchPaths(this._root);

  final String _root;

  Future<String> _dir(String name) async {
    final d = Directory('$_root/$name');
    await d.create(recursive: true);
    return d.path;
  }

  @override
  Future<String?> getApplicationSupportPath() => _dir('support');

  @override
  Future<String?> getApplicationDocumentsPath() => _dir('documents');

  @override
  Future<String?> getApplicationCachePath() => _dir('cache');

  @override
  Future<String?> getTemporaryPath() => _dir('tmp');
}

String? _logPath;

void _log(String line) {
  try {
    stdout.writeln(line);
  } on Object {
    // Окно без консоли: остаётся файл.
  }
  final path = _logPath;
  if (path != null) File(path).writeAsStringSync('$line\n', mode: FileMode.append);
}
