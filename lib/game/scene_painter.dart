import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'constants.dart';
import 'controller.dart';
import 'models.dart';
import 'sim.dart';
import 'util.dart';

class _PipeInfo {
  final int x;
  final int y;
  final List<List<int>> dirs;
  final bool flow;
  const _PipeInfo(this.x, this.y, this.dirs, this.flow);
}

/// Draws the whole scene. All coordinates are derived from the cell size `c`.
class ScenePainter {
  final AquaController ctl;
  ScenePainter(this.ctl);

  late Canvas cv;
  double c = 40;
  double tm = 0;
  final Map<String, TextPainter> _tpCache = <String, TextPainter>{};

  Sim get sim => ctl.sim;

  // ------------------------------------------------------------- helpers

  Paint _fill(Color col) => Paint()..color = col;

  Paint _stroke(Color col, double w, {StrokeCap cap = StrokeCap.butt}) => Paint()
    ..color = col
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = cap
    ..strokeJoin = StrokeJoin.round;

  RRect _rr(double x, double y, double w, double h, double r) {
    final double ww = math.max(0.0, w);
    final double hh = math.max(0.0, h);
    return RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, ww, hh), Radius.circular(math.min(r, math.min(ww, hh) / 2)));
  }

  void _circ(double x, double y, double r, Paint p) {
    cv.drawCircle(Offset(x, y), math.max(0.0, r), p);
  }

  void _oval(double cx, double cy, double rx, double ry, double rot, Paint p) {
    cv.save();
    cv.translate(cx, cy);
    cv.rotate(rot);
    cv.drawOval(
        Rect.fromCenter(center: Offset.zero, width: math.max(0.1, rx * 2), height: math.max(0.1, ry * 2)),
        p);
    cv.restore();
  }

  TextPainter _tpFor(String s, double size, Color col, FontWeight weight) {
    final String key = '$s|${size.round()}|${col.hashCode}|${weight.index}';
    TextPainter? tp = _tpCache[key];
    if (tp == null) {
      if (_tpCache.length > 400) _tpCache.clear();
      tp = TextPainter(
        text: TextSpan(text: s, style: TextStyle(fontSize: size, color: col, fontWeight: weight)),
        textDirection: TextDirection.ltr,
      )..layout();
      _tpCache[key] = tp;
    }
    return tp;
  }

  void _emoji(String ch, double x, double y, double size, [double alpha = 1.0]) {
    final TextPainter tp = _tpFor(ch, size, Colors.white, FontWeight.w400);
    final bool fade = alpha < 0.99;
    if (fade) {
      cv.saveLayer(
          Rect.fromCenter(center: Offset(x, y), width: size * 2.5, height: size * 2.5),
          Paint()..color = rgba(255, 255, 255, clampD(alpha, 0, 1)));
    }
    tp.paint(cv, Offset(x - tp.width / 2, y - tp.height / 2));
    if (fade) cv.restore();
  }

  void _dashedRRect(RRect rr, Paint p, double dash, double gap, double phase) {
    final Path path = Path()..addRRect(rr);
    final double period = dash + gap;
    for (final ui.PathMetric m in path.computeMetrics()) {
      double d = -(phase % period);
      while (d < m.length) {
        final double a = math.max(0.0, d);
        final double b = math.min(m.length, d + dash);
        if (b > a) cv.drawPath(m.extractPath(a, b), p);
        d += period;
      }
    }
  }
