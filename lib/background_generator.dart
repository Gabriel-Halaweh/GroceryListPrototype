import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class MovingIconBackgroundController {
  _MovingIconBackgroundState? _state;

  void _attach(_MovingIconBackgroundState s) => _state = s;
  void _detach(_MovingIconBackgroundState s) {
    if (_state == s) _state = null;
  }

  void transitionTo({
    double? directionX,
    double? directionY,

    double? targetSpeedX,
    double? targetSpeedY,

    double? maxSpeedX,
    double? maxSpeedY,

    Duration durationIn = const Duration(milliseconds: 300),
    Duration durationOut = const Duration(milliseconds: 700),

    Color? newBackgroundColor,
    Color? newIconColor,
    List<IconData>? newIcons,
    List<Color> backgroundColorSequence = const [],

    Curve curve = Curves.easeInOutCubic,
    double curveStrength = 1.0,
  }) {
    _state?._transitionTo(
      directionX: directionX,
      directionY: directionY,
      targetSpeedX: targetSpeedX,
      targetSpeedY: targetSpeedY,
      maxSpeedX: maxSpeedX,
      maxSpeedY: maxSpeedY,
      durationIn: durationIn,
      durationOut: durationOut,
      newBackgroundColor: newBackgroundColor,
      newIconColor: newIconColor,
      newIcons: newIcons,
      backgroundColorSequence: backgroundColorSequence,
      curve: curve,
      curveStrength: curveStrength,
    );
  }
}

class MovingIconBackground extends StatefulWidget {
  const MovingIconBackground({
    super.key,
    required this.baseSpeedX, // initial magnitude (px/sec)
    required this.baseSpeedY, // initial magnitude (px/sec)
    this.initialDirectionX = -1,
    this.initialDirectionY = -1,
    required this.iconSpacingX,
    required this.iconSpacingY,
    required this.icons,
    required this.iconSize,
    required this.backgroundColor,
    required this.iconColor,
    this.rowIconOffsetStep = 0,
    this.fixedStepHz = 120,
    this.controller,
  });

  final double baseSpeedX;
  final double baseSpeedY;

  final int initialDirectionX; // -1, 0, 1
  final int initialDirectionY; // -1, 0, 1

  final double iconSpacingX;
  final double iconSpacingY;
  final List<IconData> icons;
  final double iconSize;
  final Color backgroundColor;
  final Color iconColor;

  final int rowIconOffsetStep;
  final int fixedStepHz;

  final MovingIconBackgroundController? controller;

  @override
  State<MovingIconBackground> createState() => _MovingIconBackgroundState();
}

class _MovingIconBackgroundState extends State<MovingIconBackground>
    with TickerProviderStateMixin {
  late final Ticker _ticker;
  Duration? _lastElapsed;
  double _accum = 0.0;

  double _posX = 0.0;
  double _posY = 0.0;
  final ValueNotifier<Offset> _pos = ValueNotifier<Offset>(Offset.zero);

  late final ValueNotifier<double> _speedMagX = ValueNotifier<double>(widget.baseSpeedX.abs());
  late final ValueNotifier<double> _speedMagY = ValueNotifier<double>(widget.baseSpeedY.abs());
  final ValueNotifier<int> _dirX = ValueNotifier<int>(0);
  final ValueNotifier<int> _dirY = ValueNotifier<int>(0);

  late final ValueNotifier<Color> _bgColor = ValueNotifier<Color>(widget.backgroundColor);
  late final ValueNotifier<Color> _icColor = ValueNotifier<Color>(widget.iconColor);

  late final ValueNotifier<List<IconData>> _iconsA =
  ValueNotifier<List<IconData>>(List.of(widget.icons));
  final ValueNotifier<List<IconData>?> _iconsB = ValueNotifier<List<IconData>?>(null);
  final ValueNotifier<double> _iconsBlend = ValueNotifier<double>(0.0);

  late final AnimationController _modeCtrl;
  VoidCallback? _activeTick;
  void Function(AnimationStatus)? _activeStatus;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);

    _dirX.value = widget.initialDirectionX;
    _dirY.value = widget.initialDirectionY;

    _modeCtrl = AnimationController(vsync: this);

    final fixedDt = 1.0 / widget.fixedStepHz;

    _ticker = createTicker((elapsed) {
      final last = _lastElapsed;
      _lastElapsed = elapsed;
      if (last == null) return;

      var dt = (elapsed - last).inMicroseconds / 1e6;
      if (dt > 0.25) dt = 0.25; // guard on hitch/resume

      _accum += dt;

      int steps = 0;
      while (_accum >= fixedDt) {
        steps++;

        final vx = _speedMagX.value * _dirX.value;
        final vy = _speedMagY.value * _dirY.value;
        _posX += vx * fixedDt;
        _posY += vy * fixedDt;

        _accum -= fixedDt;
      }

      if (steps > 0) {
        _pos.value = Offset(_posX, _posY);
      }
    })..start();
  }

  @override
  void didUpdateWidget(covariant MovingIconBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);

    _cancelTransition();
    _ticker.dispose();
    _modeCtrl.dispose();

    _pos.dispose();
    _speedMagX.dispose();
    _speedMagY.dispose();
    _dirX.dispose();
    _dirY.dispose();
    _bgColor.dispose();
    _icColor.dispose();
    _iconsA.dispose();
    _iconsB.dispose();
    _iconsBlend.dispose();

    super.dispose();
  }

  static int _sign(double v) => v == 0 ? 0 : (v > 0 ? 1 : -1);

  double _shape(double t, Curve curve, double strength) {
    final tt = t.clamp(0.0, 1.0);
    final curved = curve.transform(tt);
    final s = strength.clamp(0.0, 1.0);
    return tt + (curved - tt) * s;
  }

  TweenSequence<Color?> _buildColorSequence(Color start, List<Color> mid, Color end) {
    final points = <Color>[start, ...mid, end];
    if (points.length < 2) {
      return TweenSequence<Color?>([
        TweenSequenceItem(tween: ColorTween(begin: start, end: end), weight: 1),
      ]);
    }

    final items = <TweenSequenceItem<Color?>>[];
    for (int i = 0; i < points.length - 1; i++) {
      items.add(TweenSequenceItem(
        tween: ColorTween(begin: points[i], end: points[i + 1]),
        weight: 1,
      ));
    }
    return TweenSequence<Color?>(items);
  }

  void _cancelTransition() {
    if (_activeTick != null) {
      _modeCtrl.removeListener(_activeTick!);
      _activeTick = null;
    }
    if (_activeStatus != null) {
      _modeCtrl.removeStatusListener(_activeStatus!);
      _activeStatus = null;
    }
    _modeCtrl.stop();
  }

  void _transitionTo({
    double? directionX,
    double? directionY,
    double? targetSpeedX,
    double? targetSpeedY,
    double? maxSpeedX,
    double? maxSpeedY,
    required Duration durationIn,
    required Duration durationOut,
    Color? newBackgroundColor,
    Color? newIconColor,
    List<IconData>? newIcons,
    required List<Color> backgroundColorSequence,
    required Curve curve,
    required double curveStrength,
  }) {
    _cancelTransition();

    if (directionX != null) _dirX.value = _sign(directionX);
    if (directionY != null) _dirY.value = _sign(directionY);

    final total = durationIn + durationOut;
    _modeCtrl
      ..reset()
      ..duration = total;

    final sx0 = _speedMagX.value;
    final sy0 = _speedMagY.value;

    final sxT = (targetSpeedX ?? sx0).abs();
    final syT = (targetSpeedY ?? sy0).abs();

    final sxMax = (maxSpeedX ?? sxT).abs().clamp(0.0, double.infinity);
    final syMax = (maxSpeedY ?? syT).abs().clamp(0.0, double.infinity);

    final inW = durationIn.inMilliseconds.toDouble().clamp(1.0, 1e9);
    final outW = durationOut.inMilliseconds.toDouble().clamp(1.0, 1e9);

    final sxSeq = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: sx0, end: sxMax).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: inW,
      ),
      TweenSequenceItem(
        tween: Tween(begin: sxMax, end: sxT).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: outW,
      ),
    ]);

    final sySeq = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: sy0, end: syMax).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: inW,
      ),
      TweenSequenceItem(
        tween: Tween(begin: syMax, end: syT).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: outW,
      ),
    ]);

    final bg0 = _bgColor.value;
    final ic0 = _icColor.value;
    final bg1 = newBackgroundColor ?? bg0;
    final ic1 = newIconColor ?? ic0;

    final bgSeq = _buildColorSequence(bg0, backgroundColorSequence, bg1);
    final icTween = ColorTween(begin: ic0, end: ic1);

    if (newIcons != null && newIcons.isNotEmpty) {
      _iconsB.value = List.of(newIcons);
      _iconsBlend.value = 0.0;
    } else {
      _iconsB.value = null;
      _iconsBlend.value = 0.0;
    }

    final tick = () {
      final t = _modeCtrl.value;                 // 0..1
      final p = _shape(t, curve, curveStrength); // shaped progress for colors/icons

      _speedMagX.value = sxSeq.transform(t);
      _speedMagY.value = sySeq.transform(t);

      _bgColor.value = bgSeq.transform(p) ?? bg1;
      _icColor.value = icTween.transform(p) ?? ic1;
      if (_iconsB.value != null) _iconsBlend.value = p;
    };

    final statusListener = (AnimationStatus status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        _speedMagX.value = sxT;
        _speedMagY.value = syT;
        _bgColor.value = bg1;
        _icColor.value = ic1;

        if (_iconsB.value != null) {
          _iconsA.value = _iconsB.value!;
          _iconsB.value = null;
          _iconsBlend.value = 0.0;
        }

        _cancelTransition();
      }
    };

    _activeTick = tick;
    _activeStatus = statusListener;

    _modeCtrl.addListener(tick);
    _modeCtrl.addStatusListener(statusListener);
    _modeCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: BackgroundPainter(
          repaint: Listenable.merge([
            _pos,
            _bgColor,
            _icColor,
            _iconsA,
            _iconsB,
            _iconsBlend,
          ]),
          pos: _pos,
          bgColor: _bgColor,
          iconColor: _icColor,
          iconsA: _iconsA,
          iconsB: _iconsB,
          iconsBlend: _iconsBlend,
          iconSpacingX: widget.iconSpacingX,
          iconSpacingY: widget.iconSpacingY,
          iconSize: widget.iconSize,
          rowIconOffsetStep: widget.rowIconOffsetStep,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class BackgroundPainter extends CustomPainter {
  BackgroundPainter({
    required Listenable repaint,
    required this.pos,
    required this.bgColor,
    required this.iconColor,
    required this.iconsA,
    required this.iconsB,
    required this.iconsBlend,
    required this.iconSpacingX,
    required this.iconSpacingY,
    required this.iconSize,
    required this.rowIconOffsetStep,
  }) : super(repaint: repaint);

  final ValueNotifier<Offset> pos;
  final ValueNotifier<Color> bgColor;
  final ValueNotifier<Color> iconColor;

  final ValueNotifier<List<IconData>> iconsA;
  final ValueNotifier<List<IconData>?> iconsB;
  final ValueNotifier<double> iconsBlend;

  final double iconSpacingX;
  final double iconSpacingY;
  final double iconSize;
  final int rowIconOffsetStep;

  static final Map<int, TextPainter> _tpCache = {};

  TextPainter _tpWhite(IconData icon) {
    final key = Object.hash(icon.codePoint, icon.fontFamily, icon.fontPackage, iconSize);
    return _tpCache.putIfAbsent(key, () {
      final tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: iconSize,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: Colors.white, // tinted at draw time
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return tp;
    });
  }

  void _paintTinted(Canvas canvas, TextPainter tp, Offset topLeft, Color tint, double opacity) {
    final o = opacity.clamp(0.0, 1.0);
    if (o <= 0) return;

    final rect = Rect.fromLTWH(topLeft.dx, topLeft.dy, tp.width, tp.height);

    canvas.saveLayer(rect, Paint());
    tp.paint(canvas, topLeft);
    canvas.drawRect(
      rect,
      Paint()
        ..color = tint.withOpacity(o)
        ..blendMode = BlendMode.srcIn,
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = bgColor.value);

    final a = iconsA.value;
    if (a.isEmpty || iconSpacingX <= 0 || iconSpacingY <= 0) return;

    final rawX = pos.value.dx;
    final rawY = pos.value.dy;

    final baseCol = (rawX / iconSpacingX).floor();
    final baseRow = (rawY / iconSpacingY).floor();

    final dx = rawX - baseCol * iconSpacingX;
    final dy = rawY - baseRow * iconSpacingY;

    final startX = -iconSpacingX - dx;
    final startY = -iconSpacingY - dy;

    final b = iconsB.value;
    final blend = (b == null) ? 0.0 : iconsBlend.value.clamp(0.0, 1.0);

    final tint = iconColor.value;

    int localRow = 0;
    for (double y = startY; y < size.height + iconSpacingY; y += iconSpacingY, localRow++) {
      final globalRow = baseRow + localRow;

      final rowShift = (globalRow % 2 == 0) ? iconSpacingX * 0.5 : 0.0;

      final rowStartIcon = (rowIconOffsetStep == 0)
          ? 0
          : (globalRow * rowIconOffsetStep) % a.length;

      int localCol = 0;
      for (double x = startX + rowShift; x < size.width + iconSpacingX; x += iconSpacingX, localCol++) {
        final globalCol = baseCol + localCol;

        final idxA = (rowStartIcon + globalCol) % a.length;
        final iconA = a[idxA];
        final tpA = _tpWhite(iconA);

        final cx = x + iconSpacingX / 2;
        final cy = y + iconSpacingY / 2;
        final topLeftA = Offset(cx - tpA.width / 2, cy - tpA.height / 2);

        if (blend <= 0.0 || b == null || b.isEmpty) {
          _paintTinted(canvas, tpA, topLeftA, tint, 1.0);
          continue;
        }

        final idxB = idxA % b.length;
        final iconB = b[idxB];
        final tpB = _tpWhite(iconB);
        final topLeftB = Offset(cx - tpB.width / 2, cy - tpB.height / 2);

        _paintTinted(canvas, tpA, topLeftA, tint, 1.0 - blend);
        _paintTinted(canvas, tpB, topLeftB, tint, blend);
      }
    }
  }

  @override
  bool shouldRepaint(covariant BackgroundPainter oldDelegate) => false;
}
