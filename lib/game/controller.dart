import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants.dart';
import 'models.dart';
import 'sim.dart';
import 'util.dart';

enum AquaTab { info, build, pipe, plant, store }

enum AquaTool { select, build, pipe, plant }

enum PipeMode { draw, erase }

enum SelKind { obj, pipe }

class Selection {
  final SelKind kind;
  final int id; // object id, or pipe key
  int slot;
  Selection.obj(this.id, [this.slot = -1]) : kind = SelKind.obj;
  Selection.pipe(this.id)
      : kind = SelKind.pipe,
        slot = -1;
}

class MissionStep {
  final String txt;
  final bool Function(Sim) done;
  const MissionStep(this.txt, this.done);
}

final List<MissionStep> kMission = <MissionStep>[
  MissionStep('🎯 ابنِ حوض سمك: تبويب «بناء» ← حوض سمك ← المس مكاناً في الدفيئة',
      (Sim s) => s.objs.any((GameObj o) => o is Tank)),
  MissionStep('🐟 اضغط على الحوض ثم اشترِ صغار السمك',
      (Sim s) => s.objs.any((GameObj o) => o is Tank && o.n > 0)),
  MissionStep('💨 ضع مضخة أكسجين ملاصقة للحوض',
      (Sim s) => s.objs.any((GameObj o) => o is Air && o.tank != null)),
  MissionStep('💧 ضع مضخة ماء وحوض زراعة ووصّلهما بأنابيب (تبويب «أنابيب»)',
      (Sim s) => s.objs.any((GameObj o) => o is Bed && o.net != null && o.net!.cap > 0)),
  MissionStep('🌱 ازرع بذوراً في خانات الحوض (تبويب «زراعة»)',
      (Sim s) => s.objs.any((GameObj o) => o is Bed && o.slots.any((Slot x) => x.alive))),
  MissionStep('🍽️ أطعم الأسماك بانتظام، واحصد الناضج لتربح أول نقودك',
      (Sim s) => s.statHarv + s.statFish > 0),
  MissionStep('🏆 نظامك يعمل! وسّع المزرعة وأضف مغذّياً آلياً، وراقب التنبيهات',
      (Sim s) => false),
];

class _Ptr {
  final double sx;
  final double sy;
  int lx;
  int ly;
  final bool touch;
  bool moved = false;
  _Ptr(this.sx, this.sy, this.lx, this.ly, this.touch);
}

const List<int> kSpeeds = <int>[1, 2, 4, 0];

class AquaController extends ChangeNotifier {
  Sim sim;
  final SharedPreferences? _prefs;

  AquaTab tab = AquaTab.info;
  ObjType? armed;
  Pt? pending;
  Pt? hover;
  String crop = 'lettuce';
  PipeMode pipeMode = PipeMode.draw;
  Selection? sel;
  int? delArm;

  bool introOpen = false;
  bool helpOpen = false;
  bool resetArm = false;
  int? _speedBeforeModal;

  String? toastMsg;
  String toastKind = 'info';
  Timer? _toastTimer;

  double _acc = 0;
  double _uiT = 0;
  double _saveT = 0;
  _Ptr? _ptr;

  AquaController(this.sim, this._prefs, {bool fresh = false}) {
    _wire();
    if (fresh) _openModal(intro: true);
  }

  static Future<AquaController> create() async {
    SharedPreferences? prefs;
    Sim? loaded;
    try {
      prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(kSaveKey);
      if (raw != null) {
        final dynamic j = jsonDecode(raw);
        if (j is Map<String, dynamic>) loaded = Sim.fromJson(j);
      }
    } catch (_) {
      loaded = null;
    }
    return AquaController(loaded ?? Sim(), prefs, fresh: loaded == null);
  }

  void _wire() {
    sim.onToast = showToast;
  }

  // ------------------------------------------------------------- getters

  bool get modalOpen => introOpen || helpOpen;

  AquaTool get tool {
    switch (tab) {
      case AquaTab.pipe:
        return AquaTool.pipe;
      case AquaTab.plant:
        return AquaTool.plant;
      case AquaTab.build:
        return armed != null ? AquaTool.build : AquaTool.select;
      default:
        return AquaTool.select;
    }
  }

  GameObj? get selObj {
    final Selection? s = sel;
    if (s == null || s.kind != SelKind.obj) return null;
    for (final GameObj o in sim.objs) {
      if (o.id == s.id) return o;
    }
    return null;
  }

  String get missionText => kMission[clampI(sim.missionStep, 0, kMission.length - 1)].txt;

  // -------------------------------------------------------------- toast

  void showToast(String msg, String kind) {
    toastMsg = msg;
    toastKind = kind;
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 4200), () {
      toastMsg = null;
      notifyListeners();
    });
    notifyListeners();
  }

  // --------------------------------------------------------------- loop

  void tick(double dt) {
    final double d = dt > 0.25 ? 0.25 : dt;
    if (!modalOpen && sim.speed > 0) {
      _acc = math.min(2.0, _acc + d * sim.speed);
      while (_acc >= kStep) {
        sim.stepSim(kStep);
        _acc -= kStep;
      }
    }
    sim.updateFx(d);
    _uiT += d;
    if (_uiT > 0.15) {
      _uiT = 0;
      _updateMission();
      notifyListeners();
    }
    _saveT += d;
    if (_saveT > 8) {
      _saveT = 0;
      save();
    }
  }

  void _updateMission() {
    while (sim.missionStep < kMission.length - 1 &&
        kMission[sim.missionStep].done(sim)) {
      sim.missionStep++;
    }
  }

  Future<void> save() async {
    final SharedPreferences? p = _prefs;
    if (p == null) return;
    try {
      await p.setString(kSaveKey, jsonEncode(sim.toJson()));
    } catch (_) {}
  }

  // ------------------------------------------------------------- modals

  void _openModal({bool intro = false, bool help = false}) {
    _speedBeforeModal ??= sim.speed;
    introOpen = intro;
    helpOpen = help;
    resetArm = false;
  }

  void openHelp() {
    _openModal(help: true);
    notifyListeners();
  }

  void closeModal() {
    introOpen = false;
    helpOpen = false;
    resetArm = false;
    final int? sp = _speedBeforeModal;
    _speedBeforeModal = null;
    if (sp != null) sim.speed = sp;
    notifyListeners();
  }

  /// First tap arms the reset, second tap shows the "new game" chooser.
  void resetPressed() {
    if (!resetArm) {
      resetArm = true;
      notifyListeners();
      return;
    }
    introOpen = true;
    helpOpen = false;
    resetArm = false;
    notifyListeners();
  }

  void newGame({required bool withStarter}) {
    sim = Sim();
    _wire();
    if (withStarter) sim.starter();
    sim.speed = 1;
    _speedBeforeModal = null;
    introOpen = false;
    helpOpen = false;
    resetArm = false;
    sel = null;
    armed = null;
    pending = null;
    hover = null;
    delArm = null;
    tab = AquaTab.info;
    _acc = 0;
    _updateMission();
    save();
    notifyListeners();
  }

  void cycleSpeed() {
    if (modalOpen) return;
    final int i = kSpeeds.indexOf(sim.speed);
    sim.speed = kSpeeds[(i + 1) % kSpeeds.length];
    notifyListeners();
  }

  // --------------------------------------------------------------- tabs

  void setTab(AquaTab t) {
    tab = t;
    if (t != AquaTab.build) {
      armed = null;
      pending = null;
    }
    delArm = null;
    notifyListeners();
  }

  void arm(ObjType k) {
    armed = armed == k ? null : k;
    pending = null;
    notifyListeners();
  }

  void okPlace() {
    final Pt? p = pending;
    final ObjType? k = armed;
    if (p == null || k == null) return;
    final GameObj? o = sim.placeObj(k, p.x, p.y);
    if (o != null) {
      armed = null;
      pending = null;
      sel = Selection.obj(o.id);
      tab = AquaTab.info;
      delArm = null;
      showToast('✅ تم وضع ${kTypes[k]!.name}', 'good');
    }
    notifyListeners();
  }

  void cancelPlace() {
    pending = null;
    notifyListeners();
  }

  void setCrop(String k) {
    crop = k;
    notifyListeners();
  }

  void setPipeMode(PipeMode m) {
    pipeMode = m;
    notifyListeners();
  }

  // ------------------------------------------------------------ actions

  void feed(Tank t) {
    sim.feedTank(t);
    notifyListeners();
  }

  void sell(Tank t) {
    sim.sellFish(t);
    notifyListeners();
  }

  void fry(Tank t, String k) {
    sim.buyFry(t, k);
    notifyListeners();
  }

  void harvestAll(Bed b) {
    int n = 0;
    for (int i = 0; i < b.slots.length; i++) {
      final Slot s = b.slots[i];
      if (s.alive && s.g >= 1) {
        sim.harvestSlot(b, i);
        n++;
      }
    }
    if (n == 0) showToast('لا يوجد محصول ناضج بعد', 'warn');
    notifyListeners();
  }

  void cleanDead(Bed b) {
    int n = 0;
    for (final Slot s in b.slots) {
      if (s.dead) {
        s.clear();
        n++;
      }
    }
    if (n > 0) showToast('🧹 تم تنظيف $n خانة', 'info');
    notifyListeners();
  }

  void fixPump(Pump p) {
    if (p.broken) {
      p.broken = false;
      sim.refreshNets();
      showToast('🔧 تم تنظيف المضخة', 'good');
    }
    notifyListeners();
  }

  /// Two-step delete: first press arms, second confirms.
  void deletePressed(GameObj o) {
    if (delArm == o.id) {
      delArm = null;
      sel = null;
      sim.removeObj(o);
      tab = AquaTab.info;
      notifyListeners();
      return;
    }
    final int id = o.id;
    delArm = id;
    Timer(const Duration(milliseconds: 3500), () {
      if (delArm == id) {
        delArm = null;
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void expand() {
    sim.expand();
    pending = null;
    notifyListeners();
  }

  void buyFood() {
    sim.buyFood();
    notifyListeners();
  }

  // ------------------------------------------------------------- ghost

  Pt anchor(int gx, int gy, ObjType k) {
    final TypeInfo tp = kTypes[k]!;
    final int x = clampI(gx - (tp.w - 1) ~/ 2, 0, kCols - tp.w);
    final int y = clampI(gy - (tp.h - 1) ~/ 2, 0, sim.rows - tp.h);
    return Pt(x, y);
  }

  Pt? ghostPos() {
    final ObjType? k = armed;
    if (k == null) return null;
    final Pt? h = hover;
    if (h != null) return anchor(h.x, h.y, k);
    return pending;
  }

  // ---------------------------------------------------------- selection

  void tapSelect(int gx, int gy) {
    delArm = null;
    if (!sim.inb(gx, gy)) {
      sel = null;
      setTab(AquaTab.info);
      return;
    }
    final GameObj? o = sim.grid[gy][gx];
    if (o == null) {
      if (sim.isPipe(gx, gy)) {
        sel = Selection.pipe(sim.pk(gx, gy));
      } else {
        sel = null;
      }
      setTab(AquaTab.info);
      return;
    }
    if (o is Bed) {
      final int i = sim.slotAt(o, gx, gy);
      if (i >= 0) {
        final Slot s = o.slots[i];
        if (s.has) {
          if (s.dead) {
            s.clear();
            showToast('🧹 نُظّفت الخانة', 'info');
          } else if (s.g >= 1) {
            sim.harvestSlot(o, i);
          }
        }
        sel = Selection.obj(o.id, i);
        setTab(AquaTab.info);
        return;
      }
    }
    if (o is Pump && o.broken) {
      o.broken = false;
      sim.refreshNets();
      showToast('🔧 تم تنظيف المضخة', 'good');
    }
    sel = Selection.obj(o.id);
    setTab(AquaTab.info);
  }

  // -------------------------------------------------------------- input
  // Coordinates are in "cell units" (pixels / cell size, fractional).

  void pointerDown(double cx, double cy, bool touch) {
    final int gx = cx.floor();
    final int gy = cy.floor();
    _ptr = _Ptr(cx, cy, gx, gy, touch);
    hover = Pt(gx, gy);
    final AquaTool tl = tool;
    if (tl == AquaTool.pipe) {
      sim.paintPipe(gx, gy, pipeMode == PipeMode.erase);
    } else if (tl == AquaTool.plant) {
      sim.plantAt(gx, gy, crop);
    }
    notifyListeners();
  }

  void pointerMove(double cx, double cy) {
    final int gx = cx.floor();
    final int gy = cy.floor();
    final _Ptr? p = _ptr;
    if (p == null) {
      hover = Pt(gx, gy);
      return;
    }
    hover = Pt(gx, gy);
    final double dx = cx - p.sx;
    final double dy = cy - p.sy;
    if (dx * dx + dy * dy > 0.06) p.moved = true;
    if (gx != p.lx || gy != p.ly) {
      final AquaTool tl = tool;
      if (tl == AquaTool.pipe) {
        for (final Pt c in _line(p.lx, p.ly, gx, gy)) {
          sim.paintPipe(c.x, c.y, pipeMode == PipeMode.erase);
        }
      } else if (tl == AquaTool.plant) {
        for (final Pt c in _line(p.lx, p.ly, gx, gy)) {
          sim.plantAt(c.x, c.y, crop);
        }
      }
      p.lx = gx;
      p.ly = gy;
    }
  }

  void pointerUp(double cx, double cy) {
    final _Ptr? p = _ptr;
    if (p == null) return;
    _ptr = null;
    final int gx = cx.floor();
    final int gy = cy.floor();
    final AquaTool tl = tool;
    if (tl == AquaTool.select) {
      if (!p.moved) tapSelect(gx, gy);
    } else if (tl == AquaTool.build) {
      final ObjType? k = armed;
      if (k != null) {
        final Pt pos = anchor(gx, gy, k);
        if (p.touch) {
          pending = pos;
          hover = null;
        } else {
          pending = pos;
          okPlace();
        }
      }
    }
    if (p.touch) hover = null;
    notifyListeners();
  }

  void pointerCancel() {
    _ptr = null;
    hover = null;
  }

  static List<Pt> _line(int x0, int y0, int x1, int y1) {
    final List<Pt> r = <Pt>[];
    final int dx = (x1 - x0).abs();
    final int dy = -(y1 - y0).abs();
    final int sx = x0 < x1 ? 1 : -1;
    final int sy = y0 < y1 ? 1 : -1;
    int err = dx + dy;
    int x = x0;
    int y = y0;
    while (true) {
      r.add(Pt(x, y));
      if (x == x1 && y == y1) break;
      final int e2 = 2 * err;
      if (e2 >= dy) {
        err += dy;
        x += sx;
      }
      if (e2 <= dx) {
        err += dx;
        y += sy;
      }
    }
    return r;
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }
}
