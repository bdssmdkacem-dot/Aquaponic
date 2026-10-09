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
