import 'dart:math' as math;
import 'dart:ui';

double clampD(double v, double a, double b) => v < a ? a : (v > b ? b : v);

int clampI(int v, int a, int b) => v < a ? a : (v > b ? b : v);

/// Deterministic pseudo random in [0, 1).
double hash(double n) {
  final double x = math.sin(n * 127.1 + 311.7) * 43758.5453;
  return x - x.floorToDouble();
}

Color mixc(Color a, Color b, double t) => Color.lerp(a, b, clampD(t, 0, 1))!;

Color rgba(int r, int g, int b, double a) => Color.fromRGBO(r, g, b, a);

class Pt {
  final int x;
  final int y;
  const Pt(this.x, this.y);
}
