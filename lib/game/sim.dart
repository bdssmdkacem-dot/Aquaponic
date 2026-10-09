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

    for (final int k in pipes) {
      if (par.containsKey(k)) {
        final Net n = netFor(k);
        n.pipes++;
        pipeNet[k] = n;
      }
    }

    for (final GameObj o in objs) {
      if (o is Tank) {
        o.air = 0;
        o.feeders = <Feeder>[];
      }
    }
    for (final GameObj o in objs) {
      if (o is Air || o is Feeder) {
        Tank? found;
        for (final List<int> d in kDirs) {
          final GameObj? c = at(o.x + d[0], o.y + d[1]);
          if (c is Tank) {
            found = c;
            break;
          }
        }
        if (o is Air) {
          o.tank = found;
          if (found != null) found.air++;
        } else if (o is Feeder) {
          o.tank = found;
          if (found != null) found.feeders.add(o);
        }
      }
    }
    refreshNets();
  }

  void refreshNets() {
    for (final Net n in nets) {
      n.active = n.pumps.where((Pump p) => !p.broken).length;
      n.cap = n.tanks.isNotEmpty ? n.active * kPumpCap : 0;
    }
  }

  NetStatus netStatus(Net? n) {
    if (n == null || n.tanks.isEmpty) {
      return const NetStatus(false, '✖ غير متصل بحوض سمك');
    }
    if (n.pumps.isEmpty) return const NetStatus(false, '✖ لا توجد مضخة ماء');
    if (n.active == 0) return const NetStatus(false, '🔧 كل المضخات معطلة');
    if (n.ratio < 0.7) return const NetStatus(true, '⚠ تدفق ضعيف — أضف مضخة');
    return const NetStatus(true, '✔ الماء يصل');
  }

  // -------------------------------------------------------------- feedback

  void toast(String msg, [String kind = 'info']) {
    final ToastFn? f = onToast;
    if (f != null) f(msg, kind);
  }

  void warnT(String key, String msg, String kind, [double gap = 45]) {
    final double now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    if (now - (_warnAt[key] ?? -1e9) > gap) {
      _warnAt[key] = now;
      toast(msg, kind);
    }
  }

  void addFloater(double x, double y, String txt, Color col) {
    floaters.add(Floater(x, y, txt, col));
  }

  void spawnFood(Tank o) {
    for (int i = 0; i < 10; i++) {
      parts.add(FoodPart(
        o.x + 0.4 + rng.nextDouble() * (o.w - 0.8),
        o.y + 0.3 + rng.nextDouble() * 0.3,
        0.5 + rng.nextDouble() * 0.6,
        rng.nextDouble() * 6,
        o.y + o.h - 0.4,
      ));
    }
  }

  void updateFx(double dt) {
    for (final FoodPart p in parts) {
      p.y += p.vy * dt;
      p.x += math.sin(p.y * 9 + p.ph) * 0.15 * dt;
    }
    parts.removeWhere((FoodPart p) => p.y >= p.bot);
    for (final Floater f in floaters) {
      f.age += dt;
    }
    floaters.removeWhere((Floater f) => f.age >= 1.4);
  }

  // ------------------------------------------------------------ simulation

  void stepSim(double dt) {
    t += dt;
    refreshNets();
    for (final GameObj o in objs) {
      if (o is Tank) {
        stepTank(o, dt);
      } else if (o is Pump) {
        stepPump(o, dt);
      } else if (o is Feeder) {
        stepFeeder(o, dt);
      }
    }
    for (final Net n in nets) {
      stepNet(n, dt);
    }
    final bool alive = objs.any((GameObj o) =>
        (o is Tank && o.n > 0) ||
        (o is Bed && o.slots.any((Slot s) => s.alive)));
    if ((coins < 15 && !alive) || (coins < 12 && food <= 0)) {
      poor += dt;
      if (poor > 20) {
        coins += 80;
        poor = 0;
        toast('🎁 منحة دعم للمزارعين: +80💰', 'good');
      }
    } else {
      poor = 0;
    }
  }

  void stepTank(Tank o, double dt) {
    final FishSpecies? sp = o.species;
    final int n = o.n;
    final int air = math.min(o.air, 3);
    final double d =
        (n > 0 && sp != null) ? n * (0.025 + 0.03 * o.size) * sp.o2 : 0.0;
    o.o2 = clampD(o.o2 + ((0.5 + air * 1.6) * (1 - o.o2 / 100) - d) * dt, 0, 100);
    if (n <= 0 || sp == null) {
      o.waste = math.max(2.0, o.waste - 0.02 * dt);
      o.bad = null;
      return;
    }
    o.hunger = math.min(100.0, o.hunger + sp.hunger * dt);
    o.waste = clampD(
        o.waste + n * (0.015 + 0.02 * o.size) * sp.waste * dt, 2, 100);
    double dmg = 0;
    if (o.o2 < sp.o2Min) dmg += (sp.o2Min - o.o2) * 0.05;
    if (o.waste > 55) dmg += (o.waste - 55) * 0.04;
    if (o.hunger > 70) dmg += (o.hunger - 70) * 0.04;
    if (dmg > 0) {
      o.health -= dmg * dt;
    } else {
      o.health = math.min(100.0, o.health + 0.4 * dt);
    }
    if (o.health <= 0) {
      final int k = math.max(1, (o.n * 0.25).ceil());
      o.n = math.max(0, o.n - k);
      statLost += k;
      o.health = o.n > 0 ? 40 : 100;
      if (o.n == 0) o.size = 0;
      toast('💀 نفقت $k من الأسماك في ${tankName(o)}', 'bad');
    }

    if (o.n > 0 && o.health > 40) {
      o.size = math.min(
          1.0,
          o.size +
              dt / sp.growSec * (1 - o.hunger / 100) * (o.o2 > 25 ? 1.0 : 0.3));
    }
    if (o.n > 0) {
      o.bad = TankBad(o.o2 < sp.o2Min + 8, o.waste > 50, o.hunger > 60);
    } else {
      o.bad = null;
    }
    final TankBad? b = o.bad;
    if (b != null) {
      if (b.o2) {
        warnT('o2${o.id}', '💨 الأكسجين منخفض في ${tankName(o)} — ضع مضخة أكسجين ملاصقة', 'warn');
      }
      if (b.waste) {
        warnT('w${o.id}', '☠️ الفضلات مرتفعة في ${tankName(o)} — أضف نباتات ووصّلها بمضخة وأنابيب', 'warn');
      }
      if (b.hunger) {
        warnT('h${o.id}', '🍽️ أسماك ${tankName(o)} جائعة — أطعمها', 'warn');
      }
    }
  }

  void stepPump(Pump o, double dt) {
    final Net? n = o.net;
    if (!o.broken &&
        t > 150 &&
        n != null &&
        n.tanks.isNotEmpty &&
        rng.nextDouble() < dt / 500) {
      o.broken = true;
      toast('🔧 انسدت مضخة الماء — اضغط عليها لتنظيفها', 'bad');
    }
  }

  void stepFeeder(Feeder o, double dt) {
    o.timer -= dt;
    if (o.timer > 0) return;
    o.timer = 8;
    final Tank? tk = o.tank;
    if (tk != null && tk.n > 0 && tk.hunger > 40) feedTank(tk, auto: true);
  }

  void stepNet(Net n, double dt) {
    final List<Slot> slots = <Slot>[];
    for (final Bed b in n.beds) {
      for (final Slot s in b.slots) {
        if (s.alive) slots.add(s);
      }
    }
    final double ratio =
        n.cap > 0 ? math.min(1.0, n.cap / math.max(1, slots.length)) : 0.0;
    double demand = 0;
    for (final Slot s in slots) {
      demand += kCrops[s.crop]!.nut * (s.g >= 1 ? 0.5 : 1.0) * dt;
    }
    double avail = 0;
    for (final Tank tk in n.tanks) {
      avail += math.max(0.0, tk.waste - 4);
    }
    double sup = 0;
    if (ratio > 0 && demand > 0) {
      final double req = demand * ratio;
      final double taken = math.min(req, avail);
      sup = taken / req;
      if (avail > 0) {
        for (final Tank tk in n.tanks) {
          tk.waste -= taken * math.max(0.0, tk.waste - 4) / avail;
        }
      }
    }
    n.ratio = ratio;
    for (final Bed b in n.beds) {
      bool thirsty = false;
      bool starve = false;
      for (final Slot s in b.slots) {
        if (!s.alive) continue;
        updateSlot(s, ratio, sup, dt);
        if (s.dead) continue;
        if (s.water < 30) thirsty = true;
        if (s.nut < 15) starve = true;
      }
