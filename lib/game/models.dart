import 'constants.dart';
import 'util.dart';

double _d(dynamic v, double fallback) => v is num ? v.toDouble() : fallback;
int _i(dynamic v, int fallback) => v is num ? v.toInt() : fallback;

class Slot {
  String? crop;
  double g = 0;
  double water = 0;
  double nut = 0;
  double hp = 100;
  bool dead = false;
  bool rdy = false;

  bool get has => crop != null;
  bool get alive => crop != null && !dead;

  void clear() {
    crop = null;
    g = 0;
    water = 0;
    nut = 0;
    hp = 100;
    dead = false;
    rdy = false;
  }

  void plant(String c) {
    crop = c;
    g = 0.02;
    water = 70;
    nut = 40;
    hp = 100;
    dead = false;
    rdy = false;
  }

  Map<String, dynamic> toJson() => {
        'c': crop,
        'g': g,
        'w': water,
        'n': nut,
        'h': hp,
        'd': dead,
      };

  static Slot fromJson(Map<String, dynamic> j) {
    final Slot s = Slot();
    final dynamic c = j['c'];
    s.crop = (c is String && kCrops.containsKey(c)) ? c : null;
    s.g = _d(j['g'], 0);
    s.water = _d(j['w'], 0);
    s.nut = _d(j['n'], 0);
    s.hp = _d(j['h'], 100);
    s.dead = j['d'] == true;
    if (s.crop == null) s.clear();
    s.rdy = s.alive && s.g >= 1;
    return s;
  }
}

/// A connected group of tanks, pumps, beds and pipes.
class Net {
  final List<Tank> tanks = [];
  final List<Bed> beds = [];
  final List<Pump> pumps = [];
  int pipes = 0;
  int active = 0;
  int cap = 0;
  double ratio = 1;
}

class NetStatus {
  final bool ok;
  final String text;
  const NetStatus(this.ok, this.text);
}

class TankBad {
  final bool o2;
  final bool waste;
  final bool hunger;
  const TankBad(this.o2, this.waste, this.hunger);
  bool get any => o2 || waste || hunger;
}

abstract class GameObj {
  final int id;
  final ObjType type;
  int x;
  int y;
  final int w;
  final int h;
  Net? net;

  GameObj(this.id, this.type, this.x, this.y)
      : w = kTypes[type]!.w,
        h = kTypes[type]!.h;

  Map<String, dynamic> toJson() => {'id': id, 't': type.name, 'x': x, 'y': y};
}

class Tank extends GameObj {
  String? sp;
  int n = 0;
  double size = 0;
  double hunger = 25;
  double health = 100;
  double o2 = 85;
  double waste = 5;

  // derived (not saved)
  int air = 0;
  List<Feeder> feeders = [];
  TankBad? bad;

  Tank(int id, int x, int y) : super(id, ObjType.tank, x, y);

  FishSpecies? get species => sp == null ? null : kFish[sp];

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'sp': sp,
        'n': n,
        'size': size,
        'hunger': hunger,
        'health': health,
        'o2': o2,
        'waste': waste,
      };
}

class Bed extends GameObj {
  final List<Slot> slots;
  bool thirsty = false;
  bool starve = false;

  Bed(int id, ObjType type, int x, int y)
      : slots = List<Slot>.generate(type == ObjType.bed ? 4 : 6, (int _) => Slot()),
        super(id, type, x, y);

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'slots': slots.map((Slot s) => s.toJson()).toList(),
      };
}

class Pump extends GameObj {
  bool broken = false;
  Pump(int id, int x, int y) : super(id, ObjType.pump, x, y);

  @override
  Map<String, dynamic> toJson() => {...super.toJson(), 'broken': broken};
}

class Air extends GameObj {
  Tank? tank;
  Air(int id, int x, int y) : super(id, ObjType.air, x, y);
}

class Feeder extends GameObj {
  double timer = 5;
  Tank? tank;
  Feeder(int id, int x, int y) : super(id, ObjType.feeder, x, y);

  @override
  Map<String, dynamic> toJson() => {...super.toJson(), 'timer': timer};
}

Pt slotPos(Bed b, int i) =>
    b.type == ObjType.bed ? Pt(b.x + i, b.y) : Pt(b.x + (i % 2), b.y + (i ~/ 2));

GameObj? objFromJson(Map<String, dynamic> j) {
  final int id = _i(j['id'], 0);
  final int x = _i(j['x'], 0);
  final int y = _i(j['y'], 0);
  switch (j['t']) {
    case 'tank':
      final Tank t = Tank(id, x, y);
      final dynamic sp = j['sp'];
      t.sp = (sp is String && kFish.containsKey(sp)) ? sp : null;
      t.n = _i(j['n'], 0);
      t.size = _d(j['size'], 0);
      t.hunger = _d(j['hunger'], 25);
      t.health = _d(j['health'], 100);
      t.o2 = _d(j['o2'], 85);
      t.waste = _d(j['waste'], 5);
      if (t.sp == null) t.n = 0;
      return t;
    case 'bed':
    case 'tower':
      final Bed b = Bed(id, j['t'] == 'bed' ? ObjType.bed : ObjType.tower, x, y);
      final dynamic raw = j['slots'];
      if (raw is List) {
        for (int i = 0; i < b.slots.length && i < raw.length; i++) {
          final dynamic e = raw[i];
          if (e is Map<String, dynamic>) b.slots[i] = Slot.fromJson(e);
        }
      }
      return b;
    case 'pump':
      final Pump p = Pump(id, x, y);
      p.broken = j['broken'] == true;
      return p;
    case 'air':
      return Air(id, x, y);
    case 'feeder':
      final Feeder f = Feeder(id, x, y);
      f.timer = _d(j['timer'], 5);
      return f;
    default:
      return null;
  }
}
