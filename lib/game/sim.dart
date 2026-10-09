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
      final int x