import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import '../game/constants.dart';
import '../game/controller.dart';
import '../game/scene_painter.dart';
import '../theme.dart';

class _StagePainter extends CustomPainter {
  // Reused across frames (not rebuilt per paint) so ScenePainter's internal
  // TextPainter cache for emoji glyphs actually persists and pays off.
  final ScenePainter scenePainter;
  final double time;
  _StagePainter(this.scenePainter, this.time);

  @override
  void paint(Canvas canvas, Size size) {
    scenePainter.paint(canvas, size, time);
  }

  @override
  bool shouldRepaint(covariant _StagePainter oldDelegate) => true;
}

class GameStage extends StatefulWidget {
  final AquaController ctl;
  const GameStage({super.key, required this.ctl});

  @override
  State<GameStage> createState() => _GameStageState();
}

class _GameStageState extends State<GameStage> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final ScenePainter _scenePainter;
  Duration _last = Duration.zero;
  double _wall = 0;

  @override
  void initState() {
    super.initState();
    _scenePainter = ScenePainter(widget.ctl);
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    double dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0) return;
    if (dt > 0.25) dt = 0.25;
    widget.ctl.tick(dt);
    _wall += dt;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  double _cellSize(double width) => width / kCols;

  void _down(PointerDownEvent e, double cell) {
    final Offset p = e.localPosition;
    widget.ctl.pointerDown(p.dx / cell, p.dy / cell, e.kind == PointerDeviceKind.touch);
  }

  void _move(PointerMoveEvent e, double cell) {
    final Offset p = e.localPosition;
    widget.ctl.pointerMove(p.dx / cell, p.dy / cell);
  }

  void _hover(PointerHoverEvent e, double cell) {
    final Offset p = e.localPosition;
    widget.ctl.pointerMove(p.dx / cell, p.dy / cell);
  }

  void _up(PointerUpEvent e, double cell) {
    final Offset p = e.localPosition;
    widget.ctl.pointerUp(p.dx / cell, p.dy / cell);
  }

  @override
  Widget build(BuildContext context) {
    final AquaColors ac = context.aqua;
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints cts) {
      final double w = cts.maxWidth;
      final double cell = _cellSize(w);
      final double h = cell * widget.ctl.sim.rows;
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: w,
          height: h,
          color: const Color(0xFFCFE6D9),
          child: Stack(
            children: <Widget>[
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (PointerDownEvent e) => _down(e, cell),
                onPointerMove: (PointerMoveEvent e) => _move(e, cell),
                onPointerHover: (PointerHoverEvent e) => _hover(e, cell),
                onPointerUp: (PointerUpEvent e) => _up(e, cell),
                onPointerCancel: (PointerCancelEvent e) => widget.ctl.pointerCancel(),
                child: CustomPaint(
                  size: Size(w, h),
                  painter: _StagePainter(_scenePainter, _wall),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                top: 8,
                child: _Toast(ctl: widget.ctl, colors: ac),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _Toast extends StatelessWidget {
  final AquaController ctl;
  final AquaColors colors;
  const _Toast({required this.ctl, required this.colors});

  Color _bg(String kind) {
    switch (kind) {
      case 'bad':
        return const Color(0xE6BE2630);
      case 'warn':
        return const Color(0xE6BE7000);
      case 'good':
        return const Color(0xE61E8442);
      default:
        return const Color(0xE6122A28);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctl,
      builder: (BuildContext context, Widget? _) {
        final String? msg = ctl.toastMsg;
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: msg == null ? 0 : 1,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: _bg(ctl.toastKind),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                msg ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13, height: 1.45),
              ),
            ),
          ),
        );
      },
    );
  }
}
