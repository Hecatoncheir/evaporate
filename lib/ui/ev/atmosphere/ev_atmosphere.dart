import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../design/effects.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import 'ember_field.dart';
import 'ember_paint.dart';
import 'ev_pointer.dart';
import 'film_grain.dart';
import 'static_backdrop.dart';

/// Живая атмосфера за интерфейсом: плюм пара, восходящие угли и плёночное
/// зерно — три слоя прототипа, в том же порядке снизу вверх.
///
/// Курсор слегка сдвигает плюм (параллакс), поэтому атмосфера оборачивает
/// содержимое окна, а не лежит отдельным слоем: движение мыши над
/// интерфейсом доходит и до неё. Тот же сглаженный курсор достаётся
/// содержимому через [pointerOf] — за ним сдвигаются слои обложки героя.
///
/// Кадры идут, только пока их видно:
/// * свёрнутое окно или перекрытый маршрут — ни одного кадра;
/// * неактивное окно — 30 к/с, если это разрешено в настройках;
/// * «уменьшить движение» — один неподвижный кадр, как в прототипе.
///
/// Без живого фона и искр кадры идут, только пока курсор догоняется и за
/// ним следит параллакс.
///
/// Без [EvEffectsScope] выше по дереву атмосфера неподвижна и пуста.
class EvAtmosphere extends StatefulWidget {
  const EvAtmosphere({super.key, required this.child});

  final Widget child;

  /// Курсор над окном, общий для плюма и параллакса. `null` — атмосферы
  /// выше по дереву нет.
  static EvPointer? pointerOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_PointerScope>()?.pointer;

  /// Испарить прямоугольник окна — см. [EvAtmosphereState.burstFrom].
  /// `false` — искр нет, и панель просто гаснет.
  static bool burstFrom(BuildContext context, Rect globalRect) =>
      context.findAncestorStateOfType<EvAtmosphereState>()?.burstFrom(
        globalRect,
      ) ??
      false;

  @override
  State<EvAtmosphere> createState() => EvAtmosphereState();
}

class EvAtmosphereState extends State<EvAtmosphere>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  late final AppLifecycleListener _lifecycle;
  final _repaint = _Repaint();
  final _scene = _Scene();
  final _pointer = EvPointer();
  final _clock = Stopwatch();
  Timer? _throttle;
  Duration _lastTick = Duration.zero;

  AppLifecycleState? _appState = SchedulerBinding.instance.lifecycleState;
  EvEffects? _effects;
  bool _reducedMotion = false;
  bool _tickerModeEnabled = true;

  ui.FragmentShader? _plume;
  bool _plumeUnavailable = false;
  late final ui.Image _glowSprite = makeEvEmberSprite();

  /// Испарить то, что лежит в [globalRect]: искры срываются оттуда.
  /// Без искр или при «уменьшить движение» — ничего, как в прототипе.
  bool burstFrom(Rect globalRect, {int count = 90}) {
    if (!(_effects?.sparks ?? false) || _reducedMotion) return false;
    final box = context.findRenderObject();
    if (box is! RenderBox) return false;
    final topLeft = box.globalToLocal(globalRect.topLeft);
    _scene.embers.burstFrom(topLeft & globalRect.size, count: count);
    _syncRunning();
    return true;
  }

  /// Секунды времени плюма — для тестов.
  @visibleForTesting
  double get time => _scene.time;

  /// Кадры идут: тикером или, в фоне, таймером на 30 к/с.
  @visibleForTesting
  bool get isAnimating => _ticker.isActive || _throttle != null;

  @visibleForTesting
  bool get isThrottled => _throttle != null;

  /// Шейдер загружен; `false` и при ошибке, и пока он грузится.
  @visibleForTesting
  bool get hasPlume => _plume != null;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _appState = state;
        _syncRunning();
      },
    );
    EvPlumeProgram.load().then((program) {
      if (!mounted) return;
      setState(() {
        _plume = program?.fragmentShader();
        _plumeUnavailable = program == null;
      });
    });
    // Плитка зерна одна на приложение: её же кладёт поверх себя стекло.
    EvFilmGrain.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _effects = EvEffectsScope.maybeOf(context);
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    _tickerModeEnabled = TickerMode.valuesOf(context).enabled;
    if (_reducedMotion) {
      // неподвижный кадр прототипа: t = 8, курсор в центре
      _scene.time = 8;
      _pointer.jumpTo(const Offset(0.5, 0.5));
    }
    _syncRunning();
  }

  @override
  void dispose() {
    _throttle?.cancel();
    _ticker.dispose();
    _lifecycle.dispose();
    _repaint.dispose();
    _pointer.dispose();
    _plume?.dispose();
    _glowSprite.dispose();
    super.dispose();
  }

  /// Решает, идут ли кадры и как часто.
  void _syncRunning() {
    final effects = _effects;
    final visible = switch (_appState) {
      AppLifecycleState.hidden ||
      AppLifecycleState.paused ||
      AppLifecycleState.detached => false,
      _ => true,
    };
    final wanted =
        effects != null &&
        !_reducedMotion &&
        _tickerModeEnabled &&
        visible &&
        (effects.livingBackground || effects.sparks || _parallaxSettling);
    final throttled =
        wanted &&
        effects.throttleInBackground &&
        _appState == AppLifecycleState.inactive;

    if (wanted && !throttled) {
      if (!_ticker.isActive) {
        _lastTick = Duration.zero;
        _ticker.start();
      }
    } else if (_ticker.isActive) {
      _ticker.stop();
    }

    if (throttled) {
      if (_throttle == null) {
        _clock
          ..reset()
          ..start();
        _throttle = Timer.periodic(const Duration(milliseconds: 33), (_) {
          final dt = _clock.elapsedMicroseconds / 1e6;
          _clock
            ..reset()
            ..start();
          _advance(dt);
        });
      }
    } else {
      _throttle?.cancel();
      _throttle = null;
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    _advance(dt);
  }

  /// Параллакс включён, за курсором следят, а он ещё не догнан.
  bool get _parallaxSettling =>
      (_effects?.parallax ?? false) && _pointer.isWatched && _pointer.settling;

  void _advance(double dt) {
    final seconds = math.min(dt, 0.1);
    _scene.time += seconds;
    _pointer.advance(seconds);
    final effects = _effects;
    if (effects == null) return;
    if (effects.sparks) _scene.embers.step(seconds);
    if (effects.livingBackground || effects.sparks) {
      _repaint.notify();
    } else if (!_parallaxSettling) {
      // кадры шли только ради параллакса, а курсор догнан
      _syncRunning();
    }
  }

  void _onPointer(PointerEvent event) {
    if (_reducedMotion) return;
    final size = context.size;
    if (size == null || size.isEmpty) return;
    _pointer.target = Offset(
      (event.localPosition.dx / size.width).clamp(0.0, 1.0),
      (event.localPosition.dy / size.height).clamp(0.0, 1.0),
    );
    if (!isAnimating) _syncRunning();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.evc;
    final effects = _effects;
    return _PointerScope(
      pointer: _pointer,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerHover: _onPointer,
        onPointerMove: _onPointer,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                painter: _AtmospherePainter(
                  repaint: _repaint,
                  scene: _scene,
                  pointer: _pointer,
                  colors: c,
                  devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                  quality: effects?.quality ?? EvEffectsQuality.full,
                  plume: (effects?.livingBackground ?? false) ? _plume : null,
                  staticFallback:
                      (effects?.livingBackground ?? false) && _plumeUnavailable,
                  sparks: effects?.sparks ?? false,
                  glowSprite: _glowSprite,
                  grain: (effects?.grain ?? false) ? EvFilmGrain.image : null,
                ),
              ),
            ),
            widget.child,
          ],
        ),
      ),
    );
  }
}

/// Отдаёт курсор атмосферы содержимому окна. Сам курсор не меняется,
/// поэтому зависимых не пересобирает: они слушают его напрямую.
class _PointerScope extends InheritedWidget {
  const _PointerScope({required this.pointer, required super.child});

  final EvPointer pointer;

  @override
  bool updateShouldNotify(_PointerScope old) => old.pointer != pointer;
}

/// Загрузка шейдера плюма — один раз на приложение.
abstract final class EvPlumeProgram {
  static Future<ui.FragmentProgram?>? _loading;

  /// `null`, если шейдер недоступен: тогда рисуется неподвижный фон.
  static Future<ui.FragmentProgram?> load() =>
      _loading ??= ui.FragmentProgram.fromAsset('shaders/plume.frag')
          .then<ui.FragmentProgram?>((program) => program)
          .catchError((Object error) {
            debugPrint('EvAtmosphere: шейдер плюма недоступен: $error');
            return null;
          });
}

/// Униформы плюма — контракт с `shaders/plume.frag`: индексы идут подряд
/// в порядке объявления. [pointer] — доли окна сверху вниз; шейдеру,
/// написанному под WebGL, нужна ось y снизу вверх.
void setPlumeUniforms(
  ui.FragmentShader shader, {
  required Size frame,
  required double time,
  required Offset pointer,
  required EvColors colors,
}) {
  shader
    ..setFloat(0, frame.width)
    ..setFloat(1, frame.height)
    ..setFloat(2, time)
    ..setFloat(3, pointer.dx)
    ..setFloat(4, 1 - pointer.dy)
    ..setFloat(5, colors.hot1.r)
    ..setFloat(6, colors.hot1.g)
    ..setFloat(7, colors.hot1.b)
    ..setFloat(8, colors.hot2.r)
    ..setFloat(9, colors.hot2.g)
    ..setFloat(10, colors.hot2.b)
    ..setFloat(11, colors.cool.r)
    ..setFloat(12, colors.cool.g)
    ..setFloat(13, colors.cool.b);
}

class _Repaint extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// Изменяемое состояние кадра. Художник читает его в момент рисования,
/// поэтому кадры не пересобирают виджеты.
class _Scene {
  double time = 0;
  final embers = EvEmberField();
}

class _AtmospherePainter extends CustomPainter {
  _AtmospherePainter({
    required Listenable repaint,
    required this.scene,
    required this.pointer,
    required this.colors,
    required this.devicePixelRatio,
    required this.quality,
    required this.plume,
    required this.staticFallback,
    required this.sparks,
    required this.glowSprite,
    required this.grain,
  }) : super(repaint: repaint);

  final _Scene scene;
  final EvPointer pointer;
  final EvColors colors;
  final double devicePixelRatio;
  final EvEffectsQuality quality;
  final ui.FragmentShader? plume;
  final bool staticFallback;
  final bool sparks;
  final ui.Image glowSprite;
  final ui.Image? grain;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = colors.ground);

    final shader = plume;
    if (shader != null) {
      _paintPlume(canvas, size, shader);
    } else if (staticFallback) {
      paintStaticBackdrop(canvas, size, hot: colors.hot1, vent: colors.hot2);
    }

    if (sparks) {
      // размер окна известен только здесь
      scene.embers.resize(size, quality.factor);
      paintEvEmbers(
        canvas,
        scene.embers.embers,
        sprite: glowSprite,
        hot: colors.hot2,
        cool: colors.cool,
      );
    }

    final noise = grain;
    if (noise != null) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ImageShader(
            noise,
            TileMode.repeated,
            TileMode.repeated,
            Matrix4.identity().storage,
          )
          ..blendMode = BlendMode.overlay
          ..color = const Color(0x0D000000),
      );
    }
  }

  /// Плюм рисуется в отдельную картинку уменьшенного разрешения и
  /// растягивается на окно — как холст WebGL в прототипе. Заодно в такой
  /// картинке нет преобразований, и координата пикселя в шейдере одинакова
  /// у Skia и Impeller.
  void _paintPlume(Canvas canvas, Size size, ui.FragmentShader shader) {
    final scale = quality.plumeScale(devicePixelRatio);
    final w = math.max(2, (size.width * scale).round());
    final h = math.max(2, (size.height * scale).round());
    final frame = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
    setPlumeUniforms(
      shader,
      frame: frame.size,
      time: scene.time,
      pointer: pointer.value,
      colors: colors,
    );

    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(frame, Paint()..shader = shader);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(w, h);
    picture.dispose();
    canvas.drawImageRect(
      image,
      frame,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.low,
    );
    // Холст держит свою ссылку на картинку до конца кадра.
    image.dispose();
  }

  @override
  bool shouldRepaint(_AtmospherePainter old) =>
      old.colors != colors ||
      old.devicePixelRatio != devicePixelRatio ||
      old.quality != quality ||
      old.plume != plume ||
      old.staticFallback != staticFallback ||
      old.sparks != sparks ||
      old.grain != grain;
}
