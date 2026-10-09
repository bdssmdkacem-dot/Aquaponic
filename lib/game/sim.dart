import 'dart:math' as math;
import 'dart:ui' show Color;

import 'constants.dart';
import 'models.dart';
import 'util.dart';

typedef ToastFn = void Function(String msg, String kind);

class Floater {
  final double x;
  final double y;
  final String txt;
  final Color col;
  double age = 0;
  Floater(this.x, this.y, this.txt, this.col);
}

class FoodPart {
  double x;
  double y;
  final double vy;
  final double ph;
  final double bot;
  FoodPart(this.x, this.y, this.vy, this.ph, this.bot);
}

/// Pure game logic (no Flutter dependency). All times are in game seconds.
class Sim {
  double t = 0;
  int coins = 600;
  int food = 10;
  int rows = kMinRows;
  int missionStep = 0;
  int speed = 1;
  int statHarv = 0;
  int statFish = 0;
  int statLost = 0;
  int statPlost = 0;
  int nid = 1;
  final List<GameObj> objs = <GameObj>[];
  Set<int> pipes = <int>{};

  // derived
  List<List<GameObj?>> grid = <List<GameObj?>>[];
  List<Net> nets = <Net>[];
  Map<int, Net> pipeNet = <int, Net>{};

  // runtime only
  double poor = 0;
  ToastFn? onToast;
  final math.Random rng = math.Random();
  final Map<String, double> _warnAt = <String, double>{};
  final List<Floater> floaters = <Floater>[];
  final List<FoodPart> parts = <FoodPart>[];

  Sim() {
    rebuild();
  }

  // ------------------------------------------------------------ grid helpers

  int pk(int x, int y) => y * kCols + x;

  bool inb(int x, int y) => x >= 0 && y >= 0 && x < kCols && y < rows;

  GameObj? at(int x, int y) => inb(x, y) ? grid[y][x] : null;

  bool isPipe(int x, int y) => pipes.contains(pk(x, y));

  /// True if the cell carries water (pipe, pump, tank, bed, tower).
  bool conductAt(int x, int y) {
    if (!inb(x, y)) return false;
    final GameObj? o = grid[y][x];
    if (o != null) return o is Tank || o is Bed || o is Pump;
    return isPipe(x, y);
  }

  GameObj addObj(ObjType type, int x, int y) {
    final int id = nid++;
    final GameObj o = switch (type) {
      ObjType.tank => Tank(id, x, y),
      ObjType.bed => Bed(id, ObjType.bed, x, y),
      ObjType.tower => Bed(id, ObjType.tower, x, y),
      ObjType.pump => Pump(id, x, y),
      ObjType.air => Air(id, x, y),
      ObjType.feeder => Feeder(id, x, y),
    };
    objs.add(o);
    rebuild();
    return o;
  }

  String tankName(Tank o) {
    int idx = 0;
    int n = 0;
    for (final GameObj x in objs) {
      if (x is Tank) {
        n++;
        if (identical(x, o)) idx = n;
      }
    }
    return 'حوض $idx';
  }

  // ------------------------------------------------------ networks / rebuild

  void rebuild() {
    grid = List<List<GameObj?>>.generate(
        rows, (int _) => List<GameObj?>.filled(kCols, null));
    for (final GameObj o in objs) {
      for (int j = 0; j < o.h; j++) {
        for (int i = 0; i < o.w; i++) {
          final int gx = o.x + i;
          final int gy = o.y + j;
          if (inb(gx, gy)) grid[gy][gx] = o;
        }
      }
    }
    pipes.removeWhere((int k) {
      final int x = k % kCols;
      final int y = k ~/ kCols;
      return !inb(x, y) || grid[y][x] != null;
    });

    final Map<int, int> par = <int, int>{};
    int nodeOf(int x, int y) {
      if (!inb(x, y)) return -1;
      final GameObj? o = grid[y][x];
      if (o != null) {
        return (o is Tank || o is Bed || o is Pump) ? 100000 + o.id : -1;
      }
      return isPipe(x, y) ? pk(x, y) : -1;
    }

    int find(int a) {
      int r = a;
      while (par[r] != r) {
        r = par[r]!;
      }
      int cur = a;
      while (par[cur] != r) {
        final int nx = par[cur]!;
        par[cur] = r;
        cur = nx;
      }
      return r;
    }

    bool isLine(int x, int y) => isPipe(x, y) || grid[y][x] is Pump;

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < kCols; x++) {
        final int a = nodeOf(x, y);
        if (a < 0) continue;
        par.putIfAbsent(a, () => a);
        for (final List<int> d in const <List<int>>[
          <int>[1, 0],
          <int>[0, 1]
        ]) {
          final int nx = x + d[0];
          final int ny = y + d[1];
          final int b = nodeOf(nx, ny);
          if (b < 0 || b == a) continue;
          par.putIfAbsent(b, () => b);
          if (isLine(x, y) || isLine(nx, ny)) {
            final int ra = find(a);
            final int rb = find(b);
            if (ra != rb) par[ra] = rb;
          }
        }
      }
    }

    final Map<int, Net> groups = <int, Net>{};
    nets = <Net>[];
    pipeNet = <int, Net>{};
    Net netFor(int a) {
      final int r = find(a);
      Net? n = groups[r];
      if (n == null) {
        n = Net();
        groups[r] = n;
        nets.add(n);
      }
      return n;
    }

    for (final GameObj o in objs) {
      o.net = null;
      if (o is Tank || o is Bed || o is Pump) {
        final int a = 100000 + o.id;
        if (!par.containsKey(a)) continue;
        final Net n = netFor(a);
        o.net = n;
        if (o is Tank) {
          n.tanks.add(o);
        } else if (o is Pump) {
          n.pumps.add(o);
        } else if (o is Bed) {
          n.beds.add(o);
        }
      }
    }
