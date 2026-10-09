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
   cv.drawLine(Offset(i * c, 0), Offset(i * c, h), p);
    }
    for (int j = 1; j < sim.rows; j++) {
      cv.drawLine(Offset(0, j * c), Offset(w, j * c), p);
    }
  }

  // ---------------------------------------------------------------- tank

  void _fish(double x, double y, double dir, double s, FishSpecies sp, bool flip) {
    cv.save();
    cv.translate(x, y);
    cv.scale(dir, flip ? -1.0 : 1.0);
    final Path tail = Path()
      ..moveTo(-s * .8, 0)
      ..lineTo(-s * 1.6, -s * .55)
      ..lineTo(-s * 1.6, s * .55)
      ..close();
    cv.drawPath(tail, _fill(sp.tail));
    cv.drawOval(Rect.fromCenter(center: Offset.zero, width: s * 2, height: s * 1.12), _fill(sp.body));
    cv.drawOval(Rect.fromCenter(center: Offset(s * .05, s * .2), width: s * 1.4, height: s * .44),
        _fill(rgba(255, 255, 255, .35)));
    _circ(s * .55, -s * .12, s * .17, _fill(Colors.white));
    _circ(s * .6, -s * .12, s * .09, _fill(const Color(0xFF1B2A30)));
    cv.restore();
  }

  void _tank(Tank o) {
    final double X = o.x * c, Y = o.y * c, w = o.w * c, h = o.h * c;
    cv.drawRRect(_rr(X + .08 * c, Y + h - .14 * c, w - .16 * c, .14 * c, 3), _fill(const Color(0xFF7A6347)));
    final double gx = X + .07 * c, gy = Y + .08 * c, gw = w - .14 * c, gh = h - .2 * c;
    final double wl = gy + .22 * c;
    cv.drawRRect(_rr(gx, gy, gw, gh, 7), _fill(rgba(255, 255, 255, .4)));
    final double murk = clampD((o.waste - 22) / 60, 0, 1);
    cv.save();
    cv.clipRRect(_rr(gx + 1.5, gy + 1.5, gw - 3, gh - 3, 6));
    cv.drawRect(
        Rect.fromLTWH(gx, wl, gw, gh),
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, wl), Offset(0, gy + gh), <Color>[
            mixc(const Color(0xFF8ED6F7), const Color(0xFFA3B55F), murk),
            mixc(const Color(0xFF2F86C8), const Color(0xFF587231), murk),
          ]));
    final Path wave = Path()..moveTo(gx, wl + 4);
    for (double i = 0; i <= gw; i += 6) {
      wave.lineTo(gx + i, wl + math.sin(tm * 2 + i * .09 + o.id) *1.8);
    }
    wave
      ..lineTo(gx + gw, wl + 4)
      ..close();
    cv.drawPath(wave, _fill(rgba(255, 255, 255, .4)));
    cv.drawRect(Rect.fromLTWH(gx, gy + gh - .17 * c, gw, .17 * c), _fill(const Color(0xFFB8A889)));
    final Paint pebble = _fill(const Color(0xFF9B8B70));
    final int nPeb = (gw / (.2 * c)).floor();
    for (int i = 0; i < nPeb; i++) {
      _circ(gx + (i + .5) * .2 * c, gy + gh - .085 * c + (i.isOdd ? .025 * c : -.025 * c), .04 * c, pebble);
    }
    final int air = math.min(o.air, 3);
    for (int j = 0; j < air; j++) {
      final double bx = gx + gw * (air == 1 ? .5 : (.25 + .5 * j / (air - 1)));
      cv.drawRRect(_rr(bx - .12 * c, gy + gh - .24 * c, .24 * c, .09 * c, 3), _fill(const Color(0xFF8AA0AB)));
      final Paint bub = _stroke(rgba(255, 255, 255, .85), 1.2);
      for (int k = 0; k < 6; k++) {
        final double ph = (tm * .45 + k / 6 + j * .31) % 1;
        final double by = gy + gh - .24 * c - ph * (gh - .55 * c);
        final double bxx = bx + math.sin((ph + k) * 7) * .12 * c;
        cv.drawCircle(Offset(bxx, by), (.04 + .04 * hash((k + j * 9).toDouble())) * c, bub);
      }
    }
    final FishSpecies? sp = o.species;
    if (sp != null && o.n > 0) {
      final int cnt = math.min(o.n, 14);
      final bool sick = o.health < 25;
      final double top = wl + .3 * c;
      final double bot = gy + gh - .32 * c;
      final double s = c * (.14 + .13 * o.size);
      for (int i = 0; i < cnt; i++) {
        final double r1 = hash(i * 3.1 + o.id);
        final double r2 = hash(i * 7.7 + o.id * 2);
        final double r3 = hash(i * 1.9 + o.id * 5);
        final double r4 = hash(i * 5.3 + o.id * 3);
        final double amp = (.2 + .3 * r1) * gw;
        final double spd = .3 + .5 * r2;
        final double ph = r3 * 6.28;
        final double xx = gx + gw / 2 + math.sin(tm * spd + ph) * amp * .9;
        final double dir = math.cos(tm * spd + ph) >= 0 ? 1.0 : -1.0;
        double yy = top + (bot - top) * (.1 + .8 * r4) + math.sin(tm * 1.3 + i) * .04 * c;
        if (sick) yy = wl + .16 * c + r4 * .12 * c;
        _fish(xx, yy, dir, s, sp, sick);
      }
    }
    cv.restore();
    cv.drawRRect(_rr(gx, gy, gw, gh, 7), _stroke(rgba(255, 255, 255, .92), 3));
    cv.drawRRect(_rr(gx - 1.5, gy - 1.5, gw + 3, gh + 3, 8), _stroke(rgba(50, 105, 115, .6), 1));
    if (sp != null && o.n > 0) {
      final TankBad? b = o.bad;
      final double gxx = gx + .12 * c, gyy = wl + .12 * c, gwid = .95 * c, gh2 = .075 * c;
      final List<double> vals = <double>[o.o2, o.waste, o.hunger];
      final List<Color> cols = <Color>[const Color(0xFF4CC3FF), const Color(0xFFD9A63F), const Color(0xFFF2A13A)];
      final List<bool> bads = <bool>[b != null && b.o2, b != null && b.waste, b != null && b.hunger];
      for (int i = 0; i < 3; i++) {
        final double y = gyy + i * (gh2 + .03 * c);
        cv.drawRRect(_rr(gxx, y, gwid, gh2, 2), _fill(rgba(0, 0, 0, .3)));
        cv.drawRRect(_rr(gxx, y, math.max(2.0, gwid * clampD(vals[i], 0, 100) / 100), gh2, 2),
            _fill(bads[i] ? const Color(0xFFFF4D55) : cols[i]));
      }
      final TextPainter tp = _tpFor('🐟 ${o.n}', .26 * c, Colors.white, FontWeight.w700);
      final double tw = tp.width;
      cv.drawRRect(_rr(gx + gw - tw - .34 * c, gy + gh - .46 * c, tw + .24 * c, .3 * c, 6), _fill(rgba(0, 0, 0, .4)));
      tp.paint(cv, Offset(gx + gw - tw - .22 * c, gy + gh - .31 * c - tp.height / 2));
      if (b != null && b.any && math.sin(tm * 6) > -.3) {
        _emoji('⚠️', gx + gw - .34 * c, gy + .44 * c, .36 * c);
      }
    }
  }

  // ---------------------------------------------------------- beds/tower

  void _waterWindow(double x, double y, double w, double h, bool flow) {
    cv.save();
    cv.clipRRect(_rr(x, y, w, h, 4));
    if (flow) {
      cv.drawRect(
          Rect.fromLTWH(x, y, w, h),
          Paint()
            ..shader = ui.Gradient.linear(Offset(0, y), Offset(0, y + h),
                const <Color>[Color(0xFF8FD5F7), Color(0xFF3A93D0)]));
      final Path p = Path();
      for (int k = 0; k < 2; k++) {
        final double yy = y + h * (.35 + .3 * k);
        p.moveTo(x, yy);
        for (double i = 0; i <= w; i += 5) {
          p.lineTo(x + i, yy + math.sin(tm * 2.4 + i * .12 + k) * 1.6);
        }
      }
      cv.drawPath(p, _stroke(rgba(255, 255, 255, .55), 1.5));
    } else {
      cv.drawRect(Rect.fromLTWH(x, y, w, h), _fill(const Color(0xFFD9C9A8)));
      final Path p = Path()
        ..moveTo(x + w * .2, y + h)
        ..lineTo(x + w * .35, y + h * .4)
        ..moveTo(x + w * .6, y + h)
        ..lineTo(x + w * .7, y + h * .5);
      cv.drawPath(p, _stroke(rgba(120, 90, 50, .35), 1.5));
    }
    cv.restore();
  }

  void _bed(Bed o) {
    final double X = o.x * c, Y = o.y * c, w = o.w * c;
    final Net? n = o.net;
    final bool flow = n != null && n.cap > 0;
    cv.drawRRect(_rr(X + .04 * c, Y + .7 * c, w - .08 * c, .3 * c, 4), _fill(const Color(0xFF7F6045)));
    final Paint dots = _fill(const Color(0xFF6A4E37));
    for (int i = 0; i < o.w * 4; i++) {
      _circ(X + (i + .5) * c / 4, Y + .86 * c + ((i * 7) % 3 - 1) * .03 * c, .035 * c, dots);
    }
    final RRect tray = _rr(X + .02 * c, Y + 1.02 * c, w - .04 * c, .96 * c, 6);
    cv.drawRRect(tray, _fill(const Color(0xFFB8905F)));
    cv.drawRRect(tray, _stroke(const Color(0xFF8F6A40), 2));
    _waterWindow(X + .14 * c, Y + 1.2 * c, w - .28 * c, .56 * c, flow);
    for (int i = 0; i < o.slots.length; i++) {
      final Pt p = slotPos(o, i);
      final Slot s = o.slots[i];
      if (s.has) _plant((p.x + .5) * c, (p.y + .78) * c, s);
    }
    if (o.thirsty && !flow) _emoji('🔌', X + w - .3 * c, Y + 1.5 * c, .34 * c);
  }

  void _tower(Bed o) {
    final double X = o.x * c, Y = o.y * c, w = o.w * c;
    final Net? n = o.net;
    final bool flow = n != null && n.cap > 0;
    final RRect pillar = _rr(X + w / 2 - .07 * c, Y + .05 * c, .14 * c, 3.1 * c, 3);
    cv.drawRRect(pillar, _fill(const Color(0xFFE8EEF2)));
    cv.drawRRect(pillar, _stroke(const Color(0xFFB5C3CC), 1));
    final Paint post = _fill(const Color(0xFFCFD8DE));
    cv.drawRect(Rect.fromLTWH(X + .03 * c, Y + .1 * c, .07 * c, 3.05 * c), post);
    cv.drawRect(Rect.fromLTWH(X + w - .1 * c, Y + .1 * c, .07 * c, 3.05 * c), post);
    for (int r = 0; r < 3; r++) {
      final double sy = Y + r * c + .72 * c;
      cv.drawRRect(_rr(X + .04 * c, sy, w - .08 * c, .28 * c, 4), _fill(const Color(0xFF7F6045)));
      cv.drawRect(Rect.fromLTWH(X + .06 * c, sy + .2 * c, w - .12 * c, .07 * c), _fill(const Color(0xFFA7825A)));
    }
    for (int i = 0; i < o.slots.length; i++) {
      final Pt p = slotPos(o, i);
      final Slot s = o.slots[i];
      if (s.has) _plant((p.x + .5) * c, (p.y + .76) * c, s);
    }
    final RRect basin = _rr(X + .02 * c, Y + 3.05 * c, w - .04 * c, .93 * c, 6);
    cv.drawRRect(basin, _fill(const Color(0xFFB8905F)));
    cv.drawRRect(basin, _stroke(const Color(0xFF8F6A40), 2));
    _waterWindow(X + .14 * c, Y + 3.22 * c, w - .28 * c, .5 * c, flow);
    if (o.thirsty && !flow) _emoji('🔌', X + w / 2, Y + 3.5 * c, .34 * c);
  }

  // -------------------------------------------------------------- plants

  void _plant(double cx, double by, Slot s) {
    final CropInfo cr = kCrops[s.crop]!;
    final double g = clampD(s.g, .08, 1);
    final double sz = c * (.24 + .6 * g);
    if (s.dead) {
      final Path p = Path()
        ..moveTo(cx, by)
        ..quadraticBezierTo(cx, by - sz * .6, cx + sz * .4, by - sz * .45)
        ..moveTo(cx, by)
        ..quadraticBezierTo(cx - .05 * c, by - sz * .5, cx - sz * .35, by - sz * .32);
      cv.drawPath(p, _stroke(const Color(0xFF7A5C3A), 2, cap: StrokeCap.round));
      final Paint d = _fill(const Color(0xFF8A6A44));
      _circ(cx + sz * .4, by - sz * .45, sz * .07, d);
      _circ(cx - sz * .35, by - sz * .32, sz * .07, d);
      return;
    }
    final Color col = mixc(cr.color, const Color(0xFFB8A040), clampD((100 - s.hp) / 80, 0, 1));
    final Color dark = mi