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

  // --------------------------------------------------------------- paint

  void paint(Canvas canvas, Size size, double time) {
    cv = canvas;
    tm = time;
    c = size.width / kCols;
    final double w = kCols * c;
    final double h = sim.rows * c;
    cv.save();
    cv.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final double hour = (7 + sim.t / kDaySec * 24) % 24;
    final double dl = _background(w, h, hour);
    if (ctl.tool != AquaTool.select) _grid(w, h);
    for (final GameObj o in sim.objs) {
      if (o is Tank) {
        _tank(o);
      } else if (o is Bed) {
        if (o.type == ObjType.bed) {
          _bed(o);
        } else {
          _tower(o);
        }
      } else if (o is Pump) {
        _pump(o);
      } else if (o is Air) {
        _air(o);
      } else if (o is Feeder) {
        _feeder(o);
      }
    }
    _pipes();
    final Paint food = _fill(const Color(0xFFB5834A));
    for (final FoodPart p in sim.parts) {
      _circ(p.x * c, p.y * c, .05 * c, food);
    }
    if (dl < 1) {
      cv.drawRect(Rect.fromLTWH(0, 0, w, h), _fill(rgba(10, 20, 55, .3 * (1 - dl))));
    }
    _overlays();
    cv.restore();
  }

  // ---------------------------------------------------------- background

  double _background(double w, double h, double hour) {
    final double sunH = math.sin((hour - 6) / 12 * math.pi);
    final double dl = clampD(sunH * 1.6 + .3, 0, 1);
    cv.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h),
              const <Color>[Color(0xFFE6F3EA), Color(0xFFCBE4D5)]));
    final Paint boards = _stroke(rgba(60, 110, 90, .08), 1);
    for (double x = c * 1.5; x < w; x += c * 1.5) {
      cv.drawLine(Offset(x, c * 1.3), Offset(x, h), boards);
    }
    final double sh = c * 1.3;
    cv.drawRect(
        Rect.fromLTWH(0, 0, w, sh),
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, Offset(0, sh), <Color>[
            mixc(const Color(0xFF111D40), const Color(0xFF63BDF0), dl),
            mixc(const Color(0xFF2B407A), const Color(0xFFD3F0FF), dl),
          ]));
    final bool day = hour >= 6 && hour < 18;
    final double t = day ? (hour - 6) / 12 : ((hour - 18 + 24) % 24) / 12;
    final double px = w * (.08 + .84 * t);
    final double py = sh * .9 - math.sin(t * math.pi) * sh * .62;
    if (day) {
      _circ(px, py, .36 * c, _fill(rgba(255, 224, 110, .35)));
      _circ(px, py, .2 * c, _fill(const Color(0xFFFFD95A)));
    } else {
      final Paint star = _fill(rgba(255, 255, 255, .7));
      for (int i = 0; i < 9; i++) {
        _circ(w * hash(i * 4.1), sh * .75 * hash(i * 9.7 + 1), .018 * c + hash(i.toDouble()) * .014 * c, star);
      }
      _circ(px, py, .17 * c, _fill(const Color(0xFFF3F5FF)));
    }
    final Paint cloud = _fill(rgba(255, 255, 255, .3 + .5 * dl));
    for (int k = 0; k < 2; k++) {
      final double cx = ((tm * 4 + k * w * .55) % (w + c * 2)) - c;
      cv.drawOval(Rect.fromCenter(center: Offset(cx, c * .55), width: c, height: c * .3), cloud);
      cv.drawOval(Rect.fromCenter(center: Offset(cx + c * .34, c * .44), width: c * .68, height: c * .3), cloud);
    }
    final Paint frame = _stroke(rgba(255, 255, 255, .9), 3);
    cv.drawRect(Rect.fromLTWH(1.5, 1.5, w - 3, sh - 3), frame);
    for (double x = c * 3; x < w; x += c * 3) {
      cv.drawLine(Offset(x, 0), Offset(x, sh), frame);
    }
    cv.drawRect(Rect.fromLTWH(0, sh - 1, w, 2), _fill(rgba(90, 120, 110, .35)));
    cv.drawRect(Rect.fromLTWH(0, h - .2 * c, w, .2 * c), _fill(const Color(0xFFA88F6C)));
    cv.drawRect(Rect.fromLTWH(0, h - .2 * c, w, 2), _fill(const Color(0xFF8B7355)));
    return dl;
  }

  void _grid(double w, double h) {
    final Paint p = _stroke(rgba(20, 70, 55, .14), 1);
    for (int i = 1; i < kCols; i++) {
